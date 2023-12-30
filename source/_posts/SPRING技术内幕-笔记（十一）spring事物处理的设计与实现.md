---
title: SPRING技术内幕-笔记（十一）spring事物处理的设计与实现
date: 2018-09-28 20:00:59
tags: spring
categories: spring
---
**11.1事物的创建**
TransactionInterceptor的invoke的回调过程中会使用createTransactionIfNecessary，这个方法在其基类TransactionAspectSupport中实现，期间会使用AbstractPlatformTransactionManager调用getTransaction(txAttr)，这个过程要对不同情况进行处理，得到TransactionStatus，然后塞进TransactionInfo中，最后将TransactionInfo与当前线程绑定，TransactionInfo穿插在整个事物处理过程中。
createTransactionIfNecessary的调用时序图：
<!-- more -->
![这里写图片描述](2018/09/28/SPRING技术内幕-笔记（十一）spring事物处理的设计与实现/20150716102610570.png)

```
	protected TransactionInfo createTransactionIfNecessary(
			PlatformTransactionManager tm, TransactionAttribute txAttr, final String joinpointIdentification) {

		// If no name specified, apply method identification as transaction name.
		//如果没有配置事物属性，就用方法名作为事物的名字
		if (txAttr != null && txAttr.getName() == null) {
			txAttr = new DelegatingTransactionAttribute(txAttr) {
				@Override
				public String getName() {
					return joinpointIdentification;
				}
			};
		}
        //TransactionStatus 封装了事物执行的状态信息
        TransactionStatus status = null;
		if (txAttr != null) {
			if (tm != null) {
			//使用定义好的事物属性创建事物，返回事物的状态和 事物本身，由事物处理器去完成，事物处理器重写getTransaction
			 //方法.
				status = tm.getTransaction(txAttr);
			}
			else {
				if (logger.isDebugEnabled()) {
					logger.debug("Skipping transactional joinpoint [" + joinpointIdentification +
							"] because no transaction manager has been configured");
				}
			}
		}
		//准备TransactionInfo，TransactionInfo封装了事物的配置信息以及TransactionStatus
		return prepareTransactionInfo(tm, txAttr, joinpointIdentification, status);
	}
```
prepareTransactionInfo代码清单:
```
	protected TransactionInfo prepareTransactionInfo(PlatformTransactionManager tm,
			TransactionAttribute txAttr, String joinpointIdentification, TransactionStatus status) {
        //创建新的TransactionInfo
		TransactionInfo txInfo = new TransactionInfo(tm, txAttr, joinpointIdentification);
		if (txAttr != null) {
			// We need a transaction for this method
			if (logger.isTraceEnabled()) {
				logger.trace("Getting transaction for [" + txInfo.getJoinpointIdentification() + "]");
			}
			// The transaction manager will flag an error if an incompatible tx already exists
			//为TransactionInfo 设置TransactionStatus，这个TransactionStatus比较重要，内含了事物创建过程的信息，
			//比如Transaction是由TransactionStatus持有的
			txInfo.newTransactionStatus(status);
		}
		else {
			// The TransactionInfo.hasTransaction() method will return
			// false. We created it only to preserve the integrity of
			// the ThreadLocal stack maintained in this class.
			if (logger.isTraceEnabled())
				logger.trace("Don't need to create transaction for [" + joinpointIdentification +
						"]: This method isn't transactional.");
		}

		// We always bind the TransactionInfo to the thread, even if we didn't create
		// a new transaction here. This guarantees that the TransactionInfo stack
        //将当前的TransactionInfo 与当前线程绑定，TransactionInfo 内部用一个含量持有以前的TransactionInfo ，这样
        //就会有一系列的TransactionInfo ，虽然不会创建新的事物，但是总会简历新的TransactionInfo 。
		txInfo.bindToThread();
		return txInfo;
	}
```
接下来就是AbstractPlatformTransactionManager得getTransaction，此方法提供了事物处理流程的一个模板。

```
	public final TransactionStatus getTransaction(TransactionDefinition definition) throws TransactionException {
	//doGetTransaction由事物处理器完成，比如datasourcetransactionmanager
		Object transaction = doGetTransaction();

		// Cache debug flag to avoid repeated checks.
		//缓存标志，防止重复检查
		boolean debugEnabled = logger.isDebugEnabled();

		if (definition == null) {
			// Use defaults if no transaction definition given.
			//使用默认事物处理属性，默认的配置如下:
			//	private int propagationBehavior = PROPAGATION_REQUIRED;
			//	private int isolationLevel = ISOLATION_DEFAULT;
			//	private int timeout = TIMEOUT_DEFAULT;
			//	private boolean readOnly = false;
			definition = new DefaultTransactionDefinition();
		}
        //判断当前事物是否已经存在,如果已经存在事物，那么需要根据事物属性中定义的事物传播性配置来处理事物的
        //产生.
		if (isExistingTransaction(transaction)) {
			// Existing transaction found -> check propagation behavior to find out how to behave.
			//如果当前线程存，那么在检查事物处理行为,将已经存在的事物进行处理，结果封装在
			//TransactionState中。
			return handleExistingTransaction(definition, transaction, debugEnabled);
		}

		// Check definition settings for new transaction.
		//检查事物中timeout的设置是否合理
		if (definition.getTimeout() < TransactionDefinition.TIMEOUT_DEFAULT) {
			throw new InvalidTimeoutException("Invalid transaction timeout", definition.getTimeout());
		}

		// No existing transaction found -> check propagation behavior to find out how to proceed.

		if (definition.getPropagationBehavior() == TransactionDefinition.PROPAGATION_MANDATORY) {
			throw new IllegalTransactionStateException(
					"No existing transaction found for transaction marked with propagation 'mandatory'");
		}
	//当前没有存在的事物，那么根据配置的事物属性的事物传播行为处理，比如PROPAGATION_REQUIRED，
		//PROPAGATION_REQUIRES_NEW，PROPAGATION_NESTED
		else if (definition.getPropagationBehavior() == TransactionDefinition.PROPAGATION_REQUIRED ||
				definition.getPropagationBehavior() == TransactionDefinition.PROPAGATION_REQUIRES_NEW ||
		    definition.getPropagationBehavior() == TransactionDefinition.PROPAGATION_NESTED) {
			SuspendedResourcesHolder suspendedResources = suspend(null);
			if (debugEnabled) {
				logger.debug("Creating new transaction with name [" + definition.getName() + "]: " + definition);
			}
			try {
				boolean newSynchronization = (getTransactionSynchronization() != SYNCHRONIZATION_NEVER);
			//要返回的TransactionStatus，封装事物处理情况，getTransactionSynchronization()默认为
			//SYNCHRONIZATION_ALWAYS，所以newSynchronization为true
				DefaultTransactionStatus status = newTransactionStatus(
						definition, transaction, true, newSynchronization, debugEnabled, suspendedResources);
				//创建事物的调用，由具体的事物处理器来完成。
				doBegin(transaction, definition);
				prepareSynchronization(status, definition);
				return status;
			}
			catch (RuntimeException ex) {
				resume(null, suspendedResources);
				throw ex;
			}
			catch (Error err) {
				resume(null, suspendedResources);
				throw err;
			}
		}
		else {
			// Create "empty" transaction: no actual transaction, but potentially synchronization.
			boolean newSynchronization = (getTransactionSynchronization() == SYNCHRONIZATION_ALWAYS);
			//设置事物为空，创建新的事物状态对象，没有transaction。
			return prepareTransactionStatus(definition, null, true, newSynchronization, debugEnabled, null);
		}
	}
```
AbstractPlatformTransactionManager创建事物的过程可以看到TransactionStatus的创建过程。
```
	protected DefaultTransactionStatus newTransactionStatus(
			TransactionDefinition definition, Object transaction, boolean newTransaction,
			boolean newSynchronization, boolean debug, Object suspendedResources) {
        //判断是不是新的事物，如果是新的事物，需要放到当前线程中去，
        //AbstractPlatformTransactionManager维护了一系列的threadLocal变量来保持事物的属性，比如并
        //事物并发事物隔离级别，是否有活跃的事物。
		boolean actualNewSynchronization = newSynchronization &&
				!TransactionSynchronizationManager.isSynchronizationActive();
				//使用DefaultTransactionStatus返回
		return new DefaultTransactionStatus(
				transaction, newTransaction, actualNewSynchronization,
				definition.isReadOnly(), debug, suspendedResources);
	}
```
所谓创建，首先是把创建工作较给具体的事物处理器来完成，比如dataSourceTransactionManager，把创建的事物对象哎TransactionStatus中保存，然后把其他事物的属性和线程ThreadLocal绑定。
对于线程中已经存在事物，会涉及事物传播属性的具体处理。处理逻辑在AbstractPlatformTransactionManager的handleExistingTransaction方法中：

```
private TransactionStatus handleExistingTransaction(
			TransactionDefinition definition, Object transaction, boolean debugEnabled)
			throws TransactionException {
//如果当前线程已有事物存在且当前事物的传播属性是PROPAGATION_NEVER，那么抛出异常，这种无法处理
		if (definition.getPropagationBehavior() == TransactionDefinition.PROPAGATION_NEVER) {
			throw new IllegalTransactionStateException(
					"Existing transaction found for transaction marked with propagation 'never'");
		}
         //如果当前线程存在事物并且当前事物传播属性是PROPAGATION_NOT_SUPPORTED，那么将事物挂起
		if (definition.getPropagationBehavior() == TransactionDefinition.PROPAGATION_NOT_SUPPORTED) {
			if (debugEnabled) {
				logger.debug("Suspending current transaction");
			}
			Object suspendedResources = suspend(transaction);
			boolean newSynchronization = (getTransactionSynchronization() == SYNCHRONIZATION_ALWAYS);
			//此时Transaction为null意味着事物方法不需要在事物环境中执行，同事挂起的事物记录到TransactionStatus当中
			//包含ThreadLocal对事物信息的记录
			return prepareTransactionStatus(
					definition, null, false, newSynchronization, debugEnabled, suspendedResources);
		}
//如果当前事物的传播属性是PROPAGATION_REQUIRES_NEW，那么将当前线程中已有的事物挂起，与创建事物不同的是，此处需要将已有
//事物挂起，而新建不需要这步操作
		if (definition.getPropagationBehavior() == TransactionDefinition.PROPAGATION_REQUIRES_NEW) {
			if (debugEnabled) {
				logger.debug("Suspending current transaction, creating new transaction with name [" +
						definition.getName() + "]");
			}
			SuspendedResourcesHolder suspendedResources = suspend(transaction);
			try {
				boolean newSynchronization = (getTransactionSynchronization() != SYNCHRONIZATION_NEVER);
				DefaultTransactionStatus status = newTransactionStatus(
						definition, transaction, true, newSynchronization, debugEnabled, suspendedResources);
				doBegin(transaction, definition);
				prepareSynchronization(status, definition);
				return status;
			}
			catch (RuntimeException beginEx) {
				resumeAfterBeginException(transaction, suspendedResources, beginEx);
				throw beginEx;
			}
			catch (Error beginErr) {
				resumeAfterBeginException(transaction, suspendedResources, beginErr);
				throw beginErr;
			}
		}
	//嵌套事物的创建
		if (definition.getPropagationBehavior() == TransactionDefinition.PROPAGATION_NESTED) {
			if (!isNestedTransactionAllowed()) {
				throw new NestedTransactionNotSupportedException(
						"Transaction manager does not allow nested transactions by default - " +
						"specify 'nestedTransactionAllowed' property with value 'true'");
			}
			if (debugEnabled) {
				logger.debug("Creating nested transaction with name [" + definition.getName() + "]");
			}
			if (useSavepointForNestedTransaction()) {
				// Create savepoint within existing Spring-managed transaction,
				// through the SavepointManager API implemented by TransactionStatus.
				// Usually uses JDBC 3.0 savepoints. Never activates Spring synchronization.
				//在spring事物处理中，创建事物保存点
				DefaultTransactionStatus status =
						prepareTransactionStatus(definition, transaction, false, false, debugEnabled, null);
				status.createAndHoldSavepoint();
				return status;
			}
			else {
				// Nested transaction through nested begin and commit/rollback calls.
				// Usually only for JTA: Spring synchronization might get activated here
				// in case of a pre-existing JTA transaction.
				boolean newSynchronization = (getTransactionSynchronization() != SYNCHRONIZATION_NEVER);
				DefaultTransactionStatus status = newTransactionStatus(
						definition, transaction, true, newSynchronization, debugEnabled, null);
				doBegin(transaction, definition);
				prepareSynchronization(status, definition);
				return status;
			}
		}

		// Assumably PROPAGATION_SUPPORTS or PROPAGATION_REQUIRED.
		if (debugEnabled) {
			logger.debug("Participating in existing transaction");
		}
		//判断当前事物方法中的事物配置与已有事物的属性配置是否一致，如果不一致则不执行事物的方法并且抛出异常
		if (isValidateExistingTransaction()) {
			if (definition.getIsolationLevel() != TransactionDefinition.ISOLATION_DEFAULT) {
				Integer currentIsolationLevel = TransactionSynchronizationManager.getCurrentTransactionIsolationLevel();
				if (currentIsolationLevel == null || currentIsolationLevel != definition.getIsolationLevel()) {
					Constants isoConstants = DefaultTransactionDefinition.constants;
					throw new IllegalTransactionStateException("Participating transaction with definition [" +
							definition + "] specifies isolation level which is incompatible with existing transaction: " +
							(currentIsolationLevel != null ?
									isoConstants.toCode(currentIsolationLevel, DefaultTransactionDefinition.PREFIX_ISOLATION) :
									"(unknown)"));
				}
			}
			if (!definition.isReadOnly()) {
				if (TransactionSynchronizationManager.isCurrentTransactionReadOnly()) {
					throw new IllegalTransactionStateException("Participating transaction with definition [" +
							definition + "] is not marked as read-only but existing transaction is");
				}
			}
		}
		//返回TransactionStatus，参数newTransaction为false，表示不是使用新的事物
		boolean newSynchronization = (getTransactionSynchronization() != SYNCHRONIZATION_NEVER);
		return prepareTransactionStatus(definition, transaction, false, newSynchronization, debugEnabled, null);
	}

```

**11.2事物的挂起**
事物的挂起牵扯到当前线程与事物处理信息的保存：

```
	protected final SuspendedResourcesHolder suspend(Object transaction) throws TransactionException {
		if (TransactionSynchronizationManager.isSynchronizationActive()) {
			List<TransactionSynchronization> suspendedSynchronizations = doSuspendSynchronization();
			try {
				Object suspendedResources = null;
				if (transaction != null) {
				//把挂起的事物交给具体的事物处理器去完成，如果事物处理器不支持事物挂起，就会抛出异常
					suspendedResources = doSuspend(transaction);
				}
				//设置事物处理状态信息，放到线程中去，并且重置线程中的相关的threadlocal变量
				String name = TransactionSynchronizationManager.getCurrentTransactionName();
				TransactionSynchronizationManager.setCurrentTransactionName(null);
				boolean readOnly = TransactionSynchronizationManager.isCurrentTransactionReadOnly();
				TransactionSynchronizationManager.setCurrentTransactionReadOnly(false);
				Integer isolationLevel = TransactionSynchronizationManager.getCurrentTransactionIsolationLevel();
				TransactionSynchronizationManager.setCurrentTransactionIsolationLevel(null);
				boolean wasActive = TransactionSynchronizationManager.isActualTransactionActive();
				TransactionSynchronizationManager.setActualTransactionActive(false);
				return new SuspendedResourcesHolder(
						suspendedResources, suspendedSynchronizations, name, readOnly, isolationLevel, wasActive);
			}
			catch (RuntimeException ex) {
				// doSuspend failed - original transaction is still active...
				doResumeSynchronization(suspendedSynchronizations);
				throw ex;
			}
			catch (Error err) {
				// doSuspend failed - original transaction is still active...
				//doSuspend方法失败，但是原先的事物依然存在
				doResumeSynchronization(suspendedSynchronizations);
				throw err;
			}
		}
		else if (transaction != null) {
			// Transaction active but no synchronization active.
			Object suspendedResources = doSuspend(transaction);
			return new SuspendedResourcesHolder(suspendedResources);
		}
		else {
			// Neither transaction nor synchronization active.
			return null;
		}
	}
```

**11.3  事务的提交**
commitTransactionAfterReturning方法通过直接调用事物处理器来完成事物的提交

```
	protected void commitTransactionAfterReturning(TransactionInfo txInfo) {
		if (txInfo != null && txInfo.hasTransaction()) {
			if (logger.isTraceEnabled()) {
				logger.trace("Completing transaction for [" + txInfo.getJoinpointIdentification() + "]");
			}
			//txInfo是TransactionInfo ，调用事物处理器的commit方法
			txInfo.getTransactionManager().commit(txInfo.getTransactionStatus());
		}
	}
```

AbstractPlatformTransactionManager的commit方法：

```
	public final void commit(TransactionStatus status) throws TransactionException {
	//status.isCompleted()表示事务已经结束
		if (status.isCompleted()) {
			throw new IllegalTransactionStateException(
					"Transaction is already completed - do not call commit or rollback more than once per transaction");
		}
//事务处理过程中出现异常，则进行回滚
		DefaultTransactionStatus defStatus = (DefaultTransactionStatus) status;
		if (defStatus.isLocalRollbackOnly()) {
			if (defStatus.isDebug()) {
				logger.debug("Transactional code has requested rollback");
			}
			processRollback(defStatus);
			return;
		}
		if (!shouldCommitOnGlobalRollbackOnly() && defStatus.isGlobalRollbackOnly()) {
			if (defStatus.isDebug()) {
				logger.debug("Global transaction is marked as rollback-only but transactional code requested commit");
			}
		//处理回滚
			processRollback(defStatus);
			// Throw UnexpectedRollbackException only at outermost transaction boundary
			// or if explicitly asked to.
			if (status.isNewTransaction() || isFailEarlyOnGlobalRollbackOnly()) {
				throw new UnexpectedRollbackException(
						"Transaction rolled back because it has been marked as rollback-only");
			}
			return;
		}
//最后调事务
		processCommit(defStatus);
	}
```

处理事务的提交：

```
	private void processCommit(DefaultTransactionStatus status) throws TransactionException {
		try {
			boolean beforeCompletionInvoked = false;
			try {
			// 事务的提交准备操作由具体的事物处理器完成
				prepareForCommit(status);
				triggerBeforeCommit(status);
				triggerBeforeCompletion(status);
				beforeCompletionInvoked = true;
				boolean globalRollbackOnly = false;
				if (status.isNewTransaction() || isFailEarlyOnGlobalRollbackOnly()) {
					globalRollbackOnly = status.isGlobalRollbackOnly();
				}
				//嵌套事物的处理
				if (status.hasSavepoint()) {
					if (status.isDebug()) {
						logger.debug("Releasing transaction savepoint");
					}
					status.releaseHeldSavepoint();
				}
				 //如果当前持有的事务是新建立的事物那么由具体的事务处理器完成提交，否则由已存在的事务完成提交
				else if (status.isNewTransaction()) {
					if (status.isDebug()) {
						logger.debug("Initiating transaction commit");
					}
					 //由具体的事务处理器完成提交
					doCommit(status);
				}
				// Throw UnexpectedRollbackException if we have a global rollback-only
				// marker but still didn't get a corresponding exception from commit.
				if (globalRollbackOnly) {
					throw new UnexpectedRollbackException(
							"Transaction silently rolled back because it has been marked as rollback-only");
				}
			}
			catch (UnexpectedRollbackException ex) {
				// can only be caused by doCommit
				triggerAfterCompletion(status, TransactionSynchronization.STATUS_ROLLED_BACK);
				throw ex;
			}
			catch (TransactionException ex) {
				// can only be caused by doCommit
				if (isRollbackOnCommitFailure()) {
					doRollbackOnCommitException(status, ex);
				}
				else {
					triggerAfterCompletion(status, TransactionSynchronization.STATUS_UNKNOWN);
				}
				throw ex;
			}
			catch (RuntimeException ex) {
				if (!beforeCompletionInvoked) {
					triggerBeforeCompletion(status);
				}
				doRollbackOnCommitException(status, ex);
				throw ex;
			}
			catch (Error err) {
				if (!beforeCompletionInvoked) {
					triggerBeforeCompletion(status);
				}
				doRollbackOnCommitException(status, err);
				throw err;
			}

			// Trigger afterCommit callbacks, with an exception thrown there
			// propagated to callers but the transaction still considered as committed.
			try {
			//触发triggerAfterCommit回滚
				triggerAfterCommit(status);
			}
			finally {
				triggerAfterCompletion(status, TransactionSynchronization.STATUS_COMMITTED);
			}

		}
		finally {
			cleanupAfterCompletion(status);
		}
	}
```
**11.4事务的回滚**
回滚和提交比较类似:

```
private void processRollback(DefaultTransactionStatus status) {
		try {
			try {
				triggerBeforeCompletion(status);
				//嵌套事务的回滚
				if (status.hasSavepoint()) {
					if (status.isDebug()) {
						logger.debug("Rolling back transaction to savepoint");
					}
					status.rollbackToHeldSavepoint();
				}
				 //新建事务的回滚
				else if (status.isNewTransaction()) {
					if (status.isDebug()) {
						logger.debug("Initiating transaction rollback");
					}
					doRollback(status);
				}
				//如果当前事务调用方法中，没有新建事务的回滚方法
				else if (status.hasTransaction()) {
					if (status.isLocalRollbackOnly() || isGlobalRollbackOnParticipationFailure()) {
						if (status.isDebug()) {
							logger.debug("Participating transaction failed - marking existing transaction as rollback-only");
						}
						doSetRollbackOnly(status);
					}//由线程的前一个事物来处理，当前不做任何操作
					else {
						if (status.isDebug()) {
							logger.debug("Participating transaction failed - letting transaction originator decide on rollback");
						}
					}
				}
				else {
					logger.debug("Should roll back transaction but cannot - no transaction available");
				}
			}
			catch (RuntimeException ex) {
				triggerAfterCompletion(status, TransactionSynchronization.STATUS_UNKNOWN);
				throw ex;
			}
			catch (Error err) {
				triggerAfterCompletion(status, TransactionSynchronization.STATUS_UNKNOWN);
				throw err;
			}
			triggerAfterCompletion(status, TransactionSynchronization.STATUS_ROLLED_BACK);
		}
		finally {
			cleanupAfterCompletion(status);
		}
	}
```
到此事务的处理新建，挂起，提交、回滚完成，下一步说一下具体的事物处理器对事物的处理过程。
