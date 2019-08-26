/**
*@description: This Batch class is executing and managing "LCNS Caution" Logic for "Outstanding Requirement" on related "Policy" (PolicyMaster__c)
*@author: CTS
*@date: 17th April 2018
*@version: 1.0
**/
global class LCNSCautionPolicyTaskCreationBatch implements Database.Batchable<sObject>, Database.Stateful{

    global final String policyRTName;
    global final String policyRTId;
    global IntegrationLog__c intigrationLog;
    global List<String> lcnsCautionList;
    global List<Database.SaveResult> tasksSaveResultList;
    global List<Task> allTaskRecordsList;
    global List<Database.SaveResult> policiesSaveResultList;
    global Integer allPoliciesToUpdateCount;
    global String allPoliciesToUpdate;
    
    global LCNSCautionPolicyTaskCreationBatch(String rtName, String rtId, IntegrationLog__c igLog)
    {
        intigrationLog = igLog;
        policyRTId = rtId;
        policyRTName = rtName;
        System.debug('intigrationLog Object in Trigger.new: ' + intigrationLog);
        System.debug('intigrationLog.RefreshTime__c: ' + intigrationLog.RefreshTime__c);
        System.debug('policyRTName: ' + rtName);
        System.debug('policyRTId: ' + rtId);
        
        allPoliciesToUpdateCount = 0;
        allPoliciesToUpdate = '';
        tasksSaveResultList = new List<Database.SaveResult>();
        allTaskRecordsList = new List<Task>();
        policiesSaveResultList = new List<Database.SaveResult>();
        lcnsCautionList = new List<String>();
        
        if(rtName == 'Life Policy')
        {
            System.debug('Caution: ' + System.Label.LCNS_Life_Cautions);
            lcnsCautionList = System.Label.LCNS_Life_Cautions.split(';');  
            System.debug('lcnsLifeCautionList.size: ' + lcnsCautionList.size());
        }
        else if(rtName == 'Annuity Policy')
        {
            System.debug('Caution: ' + System.Label.LCNS_Annuity_Cautions);
            lcnsCautionList = System.Label.LCNS_Annuity_Cautions.split(';');  
            System.debug('lcnsAnnuityCautionList.size: ' + lcnsCautionList.size());
        }
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC)
    {
        System.debug('** START Method Started **');
        
        return Database.getQueryLocator([Select Id, Name, First_LCNS_Caution__c, Agent__c, RecordTypeId, Agency__r.Channel__c,
                                        (Select Id, PolicyMaster__c, Requirement__c FROM OutstandingRequirements__r WHERE Requirement__c IN : lcnsCautionList) 
                                        FROM PolicyMaster__c 
                                        WHERE OutstandingRequirementsCount__c > 0 
                                        AND RecordTypeId =: policyRTId 
                                        AND First_LCNS_Caution__c = FALSE 
                                       // AND (LastModifiedDate >=: intigrationLog.RefreshTime__c OR CreatedDate >=: intigrationLog.RefreshTime__c)]);
                                        AND (LastModifiedDate >=: system.today())]);
    }
    
    global void execute(Database.BatchableContext BC, List<sObject> scope)
    {
        System.debug('** EXECUTE Method Started **');
        
        /* Map of Policies [To update the checkbox, First_LCNS_Caution__c = TRUE] after creating the Task on Policy */
        Map<ID, PolicyMaster__c> pmMapToUpdate = new Map<ID, PolicyMaster__c>();
        
        /* List of new Task to be inserted on Policy for Outstanding Requirements */
        Map<ID, Task> pmTaskMap = new Map<ID, Task>();
        
        /* List to store custom metadata "LCNSLifeAnnuityCautionOnPolicy__mdt" records */
        List<LCNSLifeAnnuityCautionOnPolicy__mdt> lcnsCautionList = new List<LCNSLifeAnnuityCautionOnPolicy__mdt>();
        
        lcnsCautionList = [SELECT LCNSCaution__c, Order__c, Category__c, CreatedByAutomation__c, Policy_RecordTypeId__c, 
                            SalesUnit__c, Status__c, Subject__c, TaskOwnerId__c, TaskOwnerName__c 
                            FROM LCNSLifeAnnuityCautionOnPolicy__mdt  Order By Order__c];
        
        String policiesToUpdate = '';
        Integer policiesToUpdateCount = 0;
        for(sObject s : scope)
        {
            PolicyMaster__c pm = (PolicyMaster__c)s;
           system.debug('pm----------'+pm);
                if(pm.OutstandingRequirements__r.size() > 0)
                {
                    system.debug('Step-1---------');
                    for(NBOutstandingRequirement__c nbor : pm.OutstandingRequirements__r)
                    {
                        system.debug('Step-2---------');
                        String nbORequirement = nbor.Requirement__c.trim().toUpperCase();
                        
                        if(!pmTaskMap.containsKey(nbor.PolicyMaster__c))
                        {
                            Task t = New Task();
                            t.ActivityDate = System.today();
                            t.Description = nbor.Requirement__c;
                            t.Sales_Unit__c = lcnsCautionList[0].SalesUnit__c;
                            t.Status = lcnsCautionList[0].Status__c;
                            t.Subject = lcnsCautionList[0].Subject__c;
                            t.WhatId = nbor.PolicyMaster__c;
                            t.WhoId = pm.Agent__c;
                            System.debug('Task IN----------');
                            if(String.valueOf(pm.RecordTypeId) == lcnsCautionList[2].Policy_RecordTypeId__c)
                            {
                                    if(System.Label.LCNS_NEWAGT_Cautions.contains(nbORequirement))
                                {
                                    t.Category__c = lcnsCautionList[1].Category__c;
                                    t.Created_by_Automation__c = lcnsCautionList[1].CreatedByAutomation__c;
                                   // t.OwnerId = lcnsCautionList[1].TaskOwnerId__c;
                                }
                                else if(System.Label.LCNS_Life_Cautions.contains(nbORequirement))
                                {
                                    t.Category__c = lcnsCautionList[2].Category__c;
                                    t.Created_by_Automation__c = lcnsCautionList[2].CreatedByAutomation__c;
                                  //  t.OwnerId = lcnsCautionList[2].TaskOwnerId__c;
                                }
                            }
                            else if(String.valueOf(pm.RecordTypeId) == lcnsCautionList[3].Policy_RecordTypeId__c && System.Label.LCNS_Annuity_Cautions.contains(nbORequirement))
                            {
                                t.Category__c = lcnsCautionList[3].Category__c;
                                t.Created_by_Automation__c = lcnsCautionList[3].CreatedByAutomation__c;
                              //  t.OwnerId = lcnsCautionList[3].TaskOwnerId__c;
                            }
                            pmTaskMap.put(nbor.PolicyMaster__c, t);
                        }
                        else{
                            if(String.valueOf(pm.RecordTypeId) == lcnsCautionList[1].Policy_RecordTypeId__c && System.Label.LCNS_NEWAGT_Cautions.contains(nbORequirement))
                            {
                                pmTaskMap.get(nbor.PolicyMaster__c).Created_by_Automation__c = lcnsCautionList[1].CreatedByAutomation__c;
                             //   pmTaskMap.get(nbor.PolicyMaster__c).OwnerId = lcnsCautionList[1].TaskOwnerId__c;
                            }
                            pmTaskMap.get(nbor.PolicyMaster__c).Description += ' / ' + nbor.Requirement__c;
                            system.debug('pmTaskMap------'+pmTaskMap);
                        }
                    }
                    
                    if(!pmMapToUpdate.containsKey(pm.Id))
                    {
                        //PolicyMaster__c pmObj = new PolicyMaster__c();
                        //pmObj.Id = pm.Id;
                        
                        pm.First_LCNS_Caution__c = true;
                        pmMapToUpdate.put(pm.Id, pm);
                        
                        policiesToUpdate += pm.Id + ',';
                        policiesToUpdateCount += 1;
                        if(System.Label.sendExceptionEmails_Switch == 'true')
                        {
                            allPoliciesToUpdate += pm.Id + ',';
                            allPoliciesToUpdateCount += 1;
                        }
                    }
                }
          }
        System.debug('policiesToUpdateCount: ' + policiesToUpdateCount);
        System.debug('policiesToUpdate: ' + policiesToUpdate);
        Map<id,Task> tskNLFA = new Map<id,Task>();
        try
        {
            if(!pmTaskMap.isEmpty())
            {
                for(Id pId : pmTaskMap.keyset())
                {
                  PolicyMaster__c pol = new PolicyMaster__c();
                  pol = pmMapToUpdate.get(pId);
                  system.debug('pol--------'+pol);
                  system.debug('pol.Agency__r.channel__c--------'+pol.Agency__r.channel__c);
                  if(pol.Agency__r.channel__c == 'NLFA')
                  {
                    if(pmTaskMap.containsKey(pol.Id))
                    {
                        Task tk = pmTaskMap.get(pol.Id);
                    	tk.ownerId = label.LCNS_Danielle_Phillips;
                        System.debug('Task Owner----------'+tk.ownerId);
                        System.debug('pmTaskMap----------'+pmTaskMap);
                    }
                   }
                }
                 System.debug('pmTaskMap----------'+pmTaskMap);
                System.debug('pmTaskMap.size before insert: ' + pmTaskMap.size());
                Database.SaveResult[] taskSRList = Database.insert(pmTaskMap.values(), false);
                if(System.Label.sendExceptionEmails_Switch == 'true')
                {
                    tasksSaveResultList.addAll(taskSRList);
                    allTaskRecordsList.addAll(pmTaskMap.values());
                }
                System.debug('pmTaskMap.size after insert: ' + pmTaskMap.size());
                System.debug('taskSRList after insert: ' + taskSRList);
            }
            if(!pmMapToUpdate.isEmpty())
            {
                System.debug('pmMapToUpdate.size before update: ' + pmMapToUpdate.size());
                Database.SaveResult[] policySRList = Database.update(pmMapToUpdate.values(), false);
                if(System.Label.sendExceptionEmails_Switch == 'true')
                {
                    policiesSaveResultList.addAll(policySRList);
                }
                System.debug('pmMapToUpdate.size after update: ' + pmMapToUpdate.size());
                System.debug('policySRList after update: ' + policySRList);
            }
        }
        catch(Exception e)
        {
            System.debug('The following exception has occurred: ' + e.getMessage());
            System.debug('Exception type caught: ' + e.getTypeName());
            System.debug('Exception Line number: ' + e.getLineNumber());
            System.debug('Exception Stack trace: ' + e.getStackTraceString());
            System.debug('Exception Cause: ' + e.getCause());    // returns null
        }
    }
    
    global void finish(Database.BatchableContext BC)
    {
        System.debug('** FINISH Method Started **');
        
        if(System.Label.sendExceptionEmails_Switch == 'true')
        {
            String successPoliciesStr = '';
            String failedPoliciesStr = '';
            Integer policyCountForSuccessRecords = 0;
            Integer policyCountForFailedRecords = 0;
            
            String successTasksStr = '';
            String failedTasksStr = '';
            Integer taskCountForSuccessRecords = 0;
            Integer taskCountForFailedRecords = 0;
            
            for(Database.SaveResult sr : policiesSaveResultList)
            {
                if (sr.isSuccess())
                {
                    // DML operation Succeeded
                    policyCountForSuccessRecords += 1;
                    successPoliciesStr += String.valueOf(sr) + '\n';
                }
                else if (!sr.isSuccess())
                {
                    // DML operation failed
                    policyCountForFailedRecords += 1;
                    String failedRecId = String.valueOf(sr.getId());
                    Database.Error error = sr.getErrors().get(0);
                    String failedRecMsg = error.getMessage();
                    
                    failedPoliciesStr += 'Failed RecordId: ' + failedRecId + '; Error Message: ' + failedRecMsg + '\n';
                }
            }
            
            for(Integer i=0;i<tasksSaveResultList.size();i++)
            {
                if (tasksSaveResultList.get(i).isSuccess())
                {
                    // DML operation Succeeded
                    taskCountForSuccessRecords += 1;
                    successTasksStr += String.valueOf(tasksSaveResultList.get(i)) + '\n';
                }
                else if (!tasksSaveResultList.get(i).isSuccess())
                {
                    // DML operation failed
                    taskCountForFailedRecords += 1;
                    String failedRecord = String.valueOf(allTaskRecordsList.get(i));
                    Database.Error error = tasksSaveResultList.get(i).getErrors().get(0);
                    String failedRecMsg = error.getMessage();
                    
                    failedTasksStr += 'Failed Record: ' + failedRecord + '; Error Message: ' + failedRecMsg + '\n';
                }
            }
            
            String resultEmailBody = 'Created-Updated or Failed Information about Tasks and Polices for LCNS Cautions: ' + '\n' + '\n'
                                        + 'Number of Eligible Policies to be Updated: ' + allPoliciesToUpdateCount + '\n' + '\n'
                                        + 'IDs of Eligible Policies to be Updated: \n' + allPoliciesToUpdate + '\n' + '\n' + '\n'
                                        
                                        + 'Number of Policies Successfully Updated: ' + policyCountForSuccessRecords + '\n' + '\n'
                                        + 'Database.SaveResult for the Policies Successfully Updated: \n' + successPoliciesStr + '\n' + '\n'
                                        
                                        + 'Number of Policies Failed to Update: ' + policyCountForFailedRecords + '\n' + '\n'
                                        + 'Failed Policy Ids With The Error Message: \n' + failedPoliciesStr + '\n' + '\n'
                                        
                                        + 'Number of Realted Tasks Successfully Inserted: ' + taskCountForSuccessRecords + '\n' + '\n'
                                        + 'Database.SaveResult for the Related Tasks Successfully Inserted: \n' + successTasksStr + '\n' + '\n'
                                        
                                        + 'Number of Tasks Failed to Insert: ' + taskCountForFailedRecords + '\n' + '\n'
                                        + 'Failed Task Records With The Error Message: \n' + failedTasksStr + '\n' + '\n';
                                        
            
            String resultSubject = 'LCNSCautionPolicyTaskCreationBatch Execution Results for LCNS Cautions';
            List<String> AdminsEmailIdsList = System.Label.NBNotifyAdminAddress.split(';');
            String[] toRecipientsEmails = AdminsEmailIdsList;
    
        //    SendExceptionEmails obj = new SendExceptionEmails();
           // obj.sendEmails(resultSubject, resultEmailBody, toRecipientsEmails);
        }
        if(policyRTName == 'Life Policy' && System.Label.SatisfiedOutReqBatch_Switch == 'true')
        {
            SendEmailViaWFlowForSatisfiedOutReqBatch obj = new SendEmailViaWFlowForSatisfiedOutReqBatch(policyRTName, policyRTId, intigrationLog);
            Integer batchScope = Integer.valueOf(System.Label.SatisfiedOutReqBatch_Scope);
            System.debug('SendEmailViaWFlowForSatisfiedOutReqBatch Scope: ' + batchScope);
            String batchID = Database.executeBatch(obj, batchScope);
            System.debug('SendEmailViaWFlowForSatisfiedOutReqBatch Batch ID: ' + batchID);
        }
    }
}