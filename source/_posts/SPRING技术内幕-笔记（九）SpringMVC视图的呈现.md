---
title: SPRING技术内幕-笔记（九）SpringMVC视图的呈现
date: 2018-09-28 19:52:05
tags: spring
categories: spring
---
**9.1 DispatcherServlet视图呈现的设计**
衔接上一章DisPatcherServlet的doDispatch,执行完handler之后得到ModelAndView对象，然后视图的展现交给了render方法：

<!-- more -->
```
	protected void render(ModelAndView mv, HttpServletRequest request, HttpServletResponse response) throws Exception {
		// Determine locale for request and apply it to the response.
		Locale locale = this.localeResolver.resolveLocale(request);
		response.setLocale(locale);

		View view;
		if (mv.isReference()) {
			// We need to resolve the view name.
			 //如果配置了String类型的view名字，那么就解析出来
			view = resolveViewName(mv.getViewName(), mv.getModelInternal(), locale, request);
			if (view == null) {
				throw new ServletException(
						"Could not resolve view with name '" + mv.getViewName() + "' in servlet with name '" +
								getServletName() + "'");
			}
		}
		else {
			// No need to lookup: the ModelAndView object contains the actual View object.
			//视图对象已经在ModelAndView 对象里边，直接拿来用
			view = mv.getView();
			if (view == null) {
				throw new ServletException("ModelAndView [" + mv + "] neither contains a view name nor a " +
						"View object in servlet with name '" + getServletName() + "'");
			}
		}

		// Delegate to the View object for rendering.
		if (logger.isDebugEnabled()) {
			logger.debug("Rendering view [" + view + "] in DispatcherServlet with name '" + getServletName() + "'");
		}
		//不同的视图类型调用各自的render方法
		view.render(mv.getModelInternal(), request, response);
	}
```
上面解析根据名字解析视图的方法resolveViewName：

```
	protected View resolveViewName(String viewName, Map<String, Object> model, Locale locale,
			HttpServletRequest request) throws Exception {

		for (ViewResolver viewResolver : this.viewResolvers) {
			View view = viewResolver.resolveViewName(viewName, locale);
			if (view != null) {
				return view;
			}
		}
		return null;
	}
```
viewResolver.resolveViewName(viewName, locale)可以看子类BeanNameViewResolver的实现：

```
	public View resolveViewName(String viewName, Locale locale) throws BeansException {
		ApplicationContext context = getApplicationContext();
		if (!context.containsBean(viewName)) {
			// Allow for ViewResolver chaining.
			return null;
		}
		return (View) context.getBean(viewName, View.class);
	}
```
可以看出直接是从山下取出来的。
回到各种视图的解析SPringMVC有各种视图的支持，PDF，JSTL，等等，使用了第三方框架，从而让视图丰富多彩。
这是SPring的视图类型结构图：

![这里写图片描述](20150624212800016.png)

**9.2JSP视图的实现**

在jsp中可以使用JSTL表达式来丰富jsp页面，在springmvc中需要Jstlview来作为view对象。
Jstlview没有实现render方法，其使用了基类的render方法：

```
	public void render(Map<String, ?> model, HttpServletRequest request, HttpServletResponse response) throws Exception {
		if (logger.isTraceEnabled()) {
			logger.trace("Rendering view with name '" + this.beanName + "' with model " + model +
				" and static attributes " + this.staticAttributes);
		}
		//将所有的数据放到一个Map里边
		Map<String, Object> mergedModel = createMergedOutputModel(model, request, response);

		prepareResponse(request, response);
		//展现模型数据到对应视图的方法
		renderMergedOutputModel(mergedModel, request, response);
	}
```
 renderMergedOutputModel使用的是模板方法，在InternalResourceView中，InternalResourceView也是Jstlview的基类，代码：


```
	protected void renderMergedOutputModel(
			Map<String, Object> model, HttpServletRequest request, HttpServletResponse response) throws Exception {

		// Determine which request handle to expose to the RequestDispatcher.
		//判断将那个请求的处理交给RequestDispatcher
		HttpServletRequest requestToExpose = getRequestToExpose(request);

		// Expose the model object as request attributes.
		//对数据进行处理，放到servletcontext中
		exposeModelAsRequestAttributes(model, requestToExpose);

		// Expose helpers as request attributes, if any.
		exposeHelpers(requestToExpose);

		// Determine the path for the request dispatcher.
		//得到InternalResourceView定义的内部资源路径
		String dispatcherPath = prepareForRendering(requestToExpose, response);

		// Obtain a RequestDispatcher for the target resource (typically a JSP).
		 //把请求转发到前面获取的资源路径中去
		RequestDispatcher rd = getRequestDispatcher(requestToExpose, dispatcherPath);
		if (rd == null) {
			throw new ServletException("Could not get RequestDispatcher for [" + getUrl() +
					"]: Check that the corresponding file exists within your web application archive!");
		}

		// If already included or response already committed, perform include, else forward.
		if (useInclude(requestToExpose, response)) {
			response.setContentType(getContentType());
			if (logger.isDebugEnabled()) {
				logger.debug("Including resource [" + getUrl() + "] in InternalResourceView '" + getBeanName() + "'");
			}
			rd.include(requestToExpose, response);
		}

		else {
			// Note: The forwarded resource is supposed to determine the content type itself.
			//转发请求到之前内部定义好的资源上去，比如jsp页面，jsp页面的展现是有容器负责，在这种情况下，view只是起到转发  
			//请求的作用
			exposeForwardRequestAttributes(requestToExpose);
			if (logger.isDebugEnabled()) {
				logger.debug("Forwarding to resource [" + getUrl() + "] in InternalResourceView '" + getBeanName() + "'");
			}
			rd.forward(requestToExpose, response);
		}
	}
```
exposeModelAsRequestAttributes(model, requestToExpose)方法是处理数据的关键，在AbstractView中他把ModelAndView中的数据以及其他请求的数据放到HttpServletRequest中去，这样就能在页面得到这些值。

```
	protected void exposeModelAsRequestAttributes(Map<String, Object> model, HttpServletRequest request) throws Exception {
		for (Map.Entry<String, Object> entry : model.entrySet()) {
			String modelName = entry.getKey();
			Object modelValue = entry.getValue();
			if (modelValue != null) {
				request.setAttribute(modelName, modelValue);
				if (logger.isDebugEnabled()) {
					logger.debug("Added model object '" + modelName + "' of type [" + modelValue.getClass().getName() +
							"] to request in view with name '" + getBeanName() + "'");
				}
			}
			else {
				request.removeAttribute(modelName);
				if (logger.isDebugEnabled()) {
					logger.debug("Removed model object '" + modelName +
							"' from request in view with name '" + getBeanName() + "'");
				}
			}
		}
	}
```

exposeHelpers包含所有关于 jstl的相关处理：

```
	protected void exposeHelpers(HttpServletRequest request) throws Exception {
		if (this.messageSource != null) {
			JstlUtils.exposeLocalizationContext(request, this.messageSource);
		}
		else {
			JstlUtils.exposeLocalizationContext(new RequestContext(request, getServletContext()));
		}
	}
```
得到转发路径后InternalResourceView进行重定向，那么这个路径的获得如下：

```
	protected String prepareForRendering(HttpServletRequest request, HttpServletResponse response)
			throws Exception {

		String path = getUrl();
		if (this.preventDispatchLoop) {
		//从request中获取URL路径
			String uri = request.getRequestURI();
			if (path.startsWith("/") ? uri.equals(path) : uri.equals(StringUtils.applyRelativePath(uri, path))) {
				throw new ServletException("Circular view path [" + path + "]: would dispatch back " +
						"to the current handler URL [" + uri + "] again. Check your ViewResolver setup! " +
						"(Hint: This may be the result of an unspecified view, due to default view name generation.)");
			}
		}
		return path;
	}
```
得到路径然后进行转发。

**9.3 ExcelView的实现**
实现类AbstractExcelView,springMvc使用了Apache开源的POI完成对excel的创建
主要实现：

```
	protected final void renderMergedOutputModel(
			Map<String, Object> model, HttpServletRequest request, HttpServletResponse response) throws Exception {

		HSSFWorkbook workbook;
		if (this.url != null) {
		//使用一游模板创建HSSFWorkbook 对象，模板来自URL
			workbook = getTemplateSource(this.url, request);
		}
		else {
		//直接New
			workbook = new HSSFWorkbook();
			logger.debug("Created Excel Workbook from scratch");
		}
        //此方法留给应用重写，完成根据去填充这张表格
		buildExcelDocument(model, workbook, request, response);

		// Set the content type.
		response.setContentType(getContentType());

		// Should we set the content length here?
		// response.setContentLength(workbook.getBytes().length);

		// Flush byte array to servlet output stream.
		//输出到页面展现
		ServletOutputStream out = response.getOutputStream();
		workbook.write(out);
		out.flush();
	}
```
从已有的文件创建	workbook对象：

```
protected HSSFWorkbook getTemplateSource(String url, HttpServletRequest request) throws Exception {
		LocalizedResourceHelper helper = new LocalizedResourceHelper(getApplicationContext());
		Locale userLocale = RequestContextUtils.getLocale(request);
		Resource inputFile = helper.findLocalizedResource(url, EXTENSION, userLocale);

		// Create the Excel document from the source.
		if (logger.isDebugEnabled()) {
			logger.debug("Loading Excel workbook from " + inputFile);
		}
		//创建excel文本对象
		POIFSFileSystem fs = new POIFSFileSystem(inputFile.getInputStream());
		return new HSSFWorkbook(fs);
	}
```
一下是一个举例解释对AbstractExcelView的使用：

```
	public void testExcelWithTemplateAndLanguage() throws Exception {
		request.setAttribute(DispatcherServlet.LOCALE_RESOLVER_ATTRIBUTE,
				newDummyLocaleResolver("de", ""));

		AbstractExcelView excelView = new AbstractExcelView() {
		 //实现基类的buildExcelDocument
			protected void buildExcelDocument(Map model, HSSFWorkbook wb,
					HttpServletRequest request, HttpServletResponse response)
					throws Exception {
				HSSFSheet sheet = wb.getSheet("Sheet1");

				// test all possible permutation of row or column not existing
				HSSFCell cell = getCell(sheet, 2, 4);
				cell.setCellValue("Test Value");
				cell = getCell(sheet, 2, 3);
				setText(cell, "Test Value");
				cell = getCell(sheet, 3, 4);
				setText(cell, "Test Value");
				cell = getCell(sheet, 2, 4);
				setText(cell, "Test Value");
			}
		};

		excelView.setApplicationContext(webAppCtx);
		excelView.setUrl("template");
		//手动调用render，触发视图的呈现
		excelView.render(new HashMap(), request, response);

		POIFSFileSystem poiFs = new POIFSFileSystem(new ByteArrayInputStream(response.getContentAsByteArray()));
		HSSFWorkbook wb = new HSSFWorkbook(poiFs);
		HSSFSheet sheet = wb.getSheet("Sheet1");
		HSSFRow row = sheet.getRow(0);
		HSSFCell cell = row.getCell((short) 0);
		assertEquals("Test Template auf Deutsch", cell.getStringCellValue());
	}
```
**9.4 PDF视图的实现**

实现类AbstractPdfView，主要的工程springMVC使用了itext：

```
	protected final void renderMergedOutputModel(
			Map<String, Object> model, HttpServletRequest request, HttpServletResponse response) throws Exception {

		// IE workaround: write into byte array first.
		ByteArrayOutputStream baos = createTemporaryOutputStream();

		// Apply preferences and build metadata.
		//创建itext与PDF文件操作相关联的对象
		Document document = newDocument();
		PdfWriter writer = newWriter(document, baos);
		prepareWriter(model, writer, request);
		buildPdfMetadata(model, document, request);

		// Build PDF document.
		//根据应用业务构建对象，填充内容，buildPdfDocument有子类去实现
		document.open();
		buildPdfDocument(model, document, writer, request, response);
		document.close();

		// Flush to HTTP response.
		writeToResponse(response, baos);
	}
```
SpringMvc提供的测试数据：

```
	public void testPdf() throws Exception {
		final String text = "this should be in the PDF";
		MockHttpServletRequest request = new MockHttpServletRequest();
		MockHttpServletResponse response = new MockHttpServletResponse();

		AbstractPdfView pdfView = new AbstractPdfView() {
			protected void buildPdfDocument(Map model, Document document, PdfWriter writer,
					HttpServletRequest request, HttpServletResponse response) throws Exception {
				document.add(new Paragraph(text));
			}
		};

		pdfView.render(new HashMap(), request, response);
		byte[] pdfContent = response.getContentAsByteArray();
		assertEquals("correct response content type", "application/pdf", response.getContentType());
		assertEquals("correct response content length", pdfContent.length, response.getContentLength());

		// rebuild iText document for comparison
		Document document = new Document(PageSize.A4);
		ByteArrayOutputStream baos = new ByteArrayOutputStream();
		PdfWriter writer = PdfWriter.getInstance(document, baos);
		writer.setViewerPreferences(PdfWriter.AllowPrinting | PdfWriter.PageLayoutSinglePage);
		document.open();
		document.add(new Paragraph(text));
		document.close();
		byte[] baosContent = baos.toByteArray();
		assertEquals("correct size", pdfContent.length, baosContent.length);

		int diffCount = 0;
		for (int i = 0; i < pdfContent.length; i++) {
			if (pdfContent[i] != baosContent[i]) {
				diffCount++;
			}
		}
		assertTrue("difference only in encryption", diffCount < 70);
	}
```
