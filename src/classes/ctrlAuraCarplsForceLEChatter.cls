/**
 * Without sharing to be safe and piss of the SFDC gods since we want to see feed items from community
 * that they might normally not allow us to see..
 *
 * @TODO this is poc only.. really really needs to be cleaned up!
 */
global without sharing class ctrlAuraCarplsForceLEChatter {

    @AuraEnabled
    public static ResponseDTO retrieveCollaborationGroup(String groupName, Id networkId, Id clientId) {
        ResponseDTO dto = retrieveCollaborationGroup(groupName,networkId);
        if(clientId != null) {
            Account a = LeHelper.retrieveClientAccount(clientId);
            dto.values.put('Account', a);
        }
        return dto;
    }
    /**
     * Gets the collaboration gropup.
     *
     * @param groupName
     *
     * @return A ResponseDTO with Collaboration group in the values map.
     *
     * @todo modify to global but i'm afraid to mod ResponseDTO to global pending more testing.
     * @todo zone in on network ID.
     * @see ResponseDTO
     */
    @AuraEnabled
    public static ResponseDTO retrieveCollaborationGroup(String groupName, Id networkId) {

        ResponseDTO dto = new ResponseDTO();
        CollaborationGroup cg;
        try {
            cg = LeHelper.retrieveCollaborationGroup(groupname,networkId);
        } catch (Exception e) {
            dto.message = 'Exception querying collaboraiton group with arg groupname=' + groupName + '...ex=' + e.getMessage();
            dto.severity = 'error';
            system.debug(logginglevel.error, e);
        }
        if (cg != null) {
            dto.isSuccess = true;
            dto.values.put('CollaborationGroup', cg);
            dto.values.put('SelectItem',new SelectItem()); //simply to make usable in Javascript.
        } else {
            dto.message = 'No Collaboration Group found for name=' + groupName + ' and networkId='+networkId;
            dto.message+= '  .An administrator has been emailed.';
            try {
                List<String> lEmails = new List<String>(((String) CustomSettingsUtls.getCarplsv20Settings(UserInfo.getUserId(), 'f4j_admin_email_addys__c')).split('~'));

                String msgBody = dto.message;
                msgBody += '<br/><br/>User was attempting to hit the local expert tab in the right hand / resource nav area<br/>';
                msgBody += '<br/>UserName that triggered this... ' + UserInfo.getUserName() + '</br>';
                msgBody += '<br/>Sooooo.... go add a the private group!</br>';
                if (!lEmails.isEmpty()) {
                    Utilities.sendEmail(lEmails, 'Carpls F4j Error Local Expert', msgBody, msgBody);
                } else {
                    Utilities.sendEmail(new List<String>{
                            'rnendza@gmail.com'
                    }, 'couldnt find email', msgBody, msgBody);
                }
            } catch (Exception e) {
                system.debug(logginglevel.error, e);
            }

        }
        return dto;
    }
    /*
    @auraenabled
    global static List<String> retrieveQuestions(Id parentId, Id caseId) {
        List<String> bogus = new List<String>();
        Set<Id> caseIds = new Set<Id>();
        caseIds.add(caseId);
        String b1 = 'parentId='+parentId + '..caseIds='+caseIds;

        List<Carpls_Case_Question__c> ccqs;
        //try {
        ccqs = [select id, feedItemId__c from carpls_case_question__c where case__c = :caseId];
        //} catch (exception e) {
        // system.debug(e);
        //}
        system.debug('ccqs=' + ccqs);
        Set<Id> caseFiIds = new Set<Id>();
        if (ccqs != null && !ccqs.isEmpty()) {
            for (Carpls_Case_Question__c ccq : ccqs) {
                caseFiIds.add(ccq.FeedItemId__c);
            }
        }

        List<FeedItem> fis = LeHelper.retrieveFeedItems(parentId, caseFiIds);
        String b2 = 'fis='+fis;
        bogus.add(b1);
        bogus.add(b2);
        return bogus;
        //return new List<String> {'parentId='+parentId + '..caseId='+caseId};
    }
    */

    @AuraEnabled
    global static List<CarplsFeedItem> retrieveQuestions(Id parentId, Id caseId) {
        //List<Object> os = new List<Object>();
        //String s = 'xxxxxparentId='+parentId + '..caseId='+caseId;
        //os.add(s);
        //return os;

        return retrieveQuestions(new Set<Id> {parentId},caseId);
    }

    @AuraEnabled
    global static List<CarplsFeedItem> retrieveQuestions(List<Id> lParentIds, Id caseId) {
        Set<Id> sParentIds = new Set<Id>();
        sParentIds.addAll(lParentIds);
        return retrieveQuestions(sParentIds,caseId);
    }
    /**
     * Retrieve a List of CarplsFeedItems with CarplsFeedComment children. for the passed parentId and caseId
     *
     * @param parentId
     * @param caseId
     *
     * @return a list of wrappers of FeedItems (CarplsFeedItem) and their child feedcomments
     * @see CarplsFeedItem
     * @see CarplsFeedComment
     *
     * @todo rename this it's crazy long
     * @todo do we need so nmany other queries? clean this up!
     * @todo convert to return DTO
     */
    global static List<CarplsFeedItem> retrieveQuestions(Set<Id> parentIds, Id caseId) {
        //List<Object> os = new List<Object>();
        //String s = 'parentIds='+parentIds + '..caseId='+caseId;
        //os.add(s);
        //return os;

        List<CarplsFeedItem> carplsFis = new List<CarplsFeedItem>();
        if (parentIds == null) {
            system.debug(logginglevel.warn, 'Null parentId passed! We cant do anything! Exiting now returning empty list');
            return carplsFis;
        }
        if (caseId == null) {
            system.debug(logginglevel.warn, 'Null caseId passed! We cant do anything! Exiting now returning empty list');
            return carplsFis;
        }

        Set<Id> caseFiIds = new Set<Id>();
        List<Carpls_Case_Question__c> ccqs;
        //try {
            ccqs = [select id, feedItemId__c from carpls_case_question__c where case__c = :caseId];
        //} catch (exception e) {
           // system.debug(e);
        //}
        system.debug('ccqs=' + ccqs);
        if (ccqs != null && !ccqs.isEmpty()) {
            for (Carpls_Case_Question__c ccq : ccqs) {
                caseFiIds.add(ccq.FeedItemId__c);
            }
        }
        List<FeedItem> fis = LeHelper.retrieveFeedItems(parentIds,caseFiIds);
       // List<CarplsFeedItem> tmpFis = new List<CarplsFeedItem>();

       // for(FeedItem fi : fis) {
       //     tmpFis.add(new CarplsFeedItem(fi));
       // }
        //return tmpFis;
        //List<CarplsFeedItem> tcarplsFis.add(new CarplsFeedItem(fi));

        //@TODO rjn is the below needed?
        //type = 'QuestionPost'

        //Well since there is no user way to get a photo url from feeditem other then the chatterconnect api
        //which blows since it forces running under the context user and disobeys without sharing so...
        // we have to do this crap.. lame!
        Set<Id> userIds = new Set<Id>();
        Set<Id> cgIds = new Set<Id>();
        Set<Id> createdbyIds = new Set<Id>();
        Set<Id> fiIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
        Set<Id> arIds = new Set<Id>();
        for (FeedItem fi : fis) {
            fiIds.add(fi.id);
            system.debug('parent.type=' + fi.parent.type);
            if (fi.Parent.Type == 'User') { //dangerous. will these always be of type user?
                userIds.add(fi.parent.id);
            } else if (fi.Parent.Type == 'CollaborationGroup') {
                cgIds.add(fi.parent.id);
            } else if (fi.parent.type == 'Account') {
                accountIds.add(fi.parent.id);
            } else if (fi.parent.type == 'Applied_Resource__c') {
                arIds.add(fi.parent.id);
            }
            if (fi.createdBy.Type == 'User') {
                createdByIds.add(fi.createdById);
            }
        }
        if (!userIds.isEmpty()) {
            Map<Id, User> mUid_parentUser = new Map<Id, User>([
                    select id, username, smallphotourl
                    from user
                    where id in :userIds
            ]);
            if (!mUid_parentUser.isEmpty()) {
                for (FeedItem fi : fis) {
                    CarplsFeedItem cfi = new CarplsFeedItem(fi);
                    for (Id uid : mUid_parentUser.keySet()) {
                        if (mUid_parentUser.containsKey(fi.parent.id)) {
                            cfi.fiParentUser = mUid_parentUser.get(fi.parent.id);
                            carplsFis.add(cfi);
                            break;
                        }

                    }
                }
            } else {
                //we should never hit this but just in case..
                for (FeedItem fi : fis) {
                    carplsFis.add(new CarplsFeedItem(fi));
                }
            }
        }
        if (!accountIds.isEmpty()) {
            Map<Id, Account> mAcct_parentAcct = new Map<Id, Account>([
                    select id, name
                    from account
                    where id in :accountIds
            ]);
            if (!mAcct_parentAcct.isEmpty()) {
                for (FeedItem fi : fis) {
                    CarplsFeedItem cfi = new CarplsFeedItem(fi);
                    for (Id acctId : mAcct_parentAcct.keySet()) {
                        if (mAcct_parentAcct.containsKey(fi.parent.id)) {
                            cfi.fiParentAcct = mAcct_parentAcct.get(fi.parent.id);
                            carplsFis.add(cfi);
                            break;
                        }

                    }
                }
            } else {
                //we should never hit this but just in case..
                for (FeedItem fi : fis) {
                    carplsFis.add(new CarplsFeedItem(fi));
                }
            }
        }
        if (!arIds.isEmpty()) {
            Map<Id, Applied_Resource__c> mAr_parentAr = new Map<Id, Applied_Resource__c>([
                    select id, name
                    from applied_resource__c
                    where id in :arIds
            ]);
            if (!mAr_parentAr.isEmpty()) {
                for (FeedItem fi : fis) {
                    CarplsFeedItem cfi = new CarplsFeedItem(fi);
                    for (Id arId : mAr_parentAr.keySet()) {
                        if (mAr_parentAr.containsKey(fi.parent.id)) {
                            cfi.fiParentAr = mAr_parentAr.get(fi.parent.id);
                            carplsFis.add(cfi);
                            break;
                        }

                    }
                }
            } else {
                //we should never hit this but just in case..
                for (FeedItem fi : fis) {
                    carplsFis.add(new CarplsFeedItem(fi));
                }
            }
        }
        if(!cgIds.isEmpty()) {
            system.debug('at cgids');
            Map<Id, CollaborationGroup> mUid_parentCg = LeHelper.retrieveCollaborationGroups(cgIds);

            if (!mUid_parentCg.isEmpty()) {
                for (FeedItem fi : fis) {
                    CarplsFeedItem cfi = new CarplsFeedItem(fi);
                    for (Id cgId : mUid_parentCg.keySet()) {
                        if (mUid_parentCg.containsKey(fi.parent.id)) {
                            cfi.fiParentCg = mUid_parentCg.get(fi.parent.id);
                            carplsFis.add(cfi);
                            break;
                        }

                    }
                }
            } else {
                system.debug('no user or cg info found.. just adding fi to array');
                for (FeedItem fi : fis) {
                    carplsFis.add(new CarplsFeedItem(fi));
                }
            }
        }
        if (!createdByIds.isEmpty()) {
            Map<Id, User> mUid_createdByUSer = LeHelper.retrieveUsers(createdbyIds);

            Map<Id, Carpls_Case_Question__c> mCcqId_CCQ = new Map<Id, Carpls_Case_Question__c>([
                    select id, feeditemid__c, best_answer__c
                    from Carpls_Case_Question__c
                    where feeditemid__c in :fiIds
            ]);

            Map<String, Carpls_Case_Question__c> mFiId_CCQ = new Map<String, Carpls_Case_Question__c>();

            if (!mCcqId_CCQ.isEmpty()) {
                for (ID ccqId : mCcqId_CCQ.keySet()) {
                    Carpls_Case_Question__c ccq = mCcqId_CCQ.get(ccqId);
                    mFiId_CCQ.put(ccq.FeedItemId__c, ccq);
                }
            }


            if (!mUid_createdByUSer.isEmpty()) {
                for (CarplsFeedItem cfi : carplsFis) {
                    for (Id uId : mUid_createdByUSer.keySet()) {
                        if (mUid_createdByUSer.containsKey(cfi.fi.createdbyid)) {
                            cfi.fiCreatedByUser = mUid_createdByUSer.get(cfi.fi.createdbyid);
                            //carplsFis.add(cfi);
                            //break;
                        }

                    }
                    if (mFiId_CCQ.containsKey(cfi.fi.id)) {
                        cfi.ccq = mFiId_CCQ.get(cfi.fi.id);
                    }
                }
            }
        }
        return carplsFis;
    }
    /**
    * Queries Topic.Name If a Topic Record(s) Exists.
    * Creates TopicAssignment Record(s) to Associate the FeedItem to the Topic.
    *
    * @param fi         The FeedItem record ie. Question
    * @param network    The Network. ie used for community tagging.
    * @param topicNames The topicNames.  ie Topic.Name
    *
    * @return a ResponseDTO a generic wrapped object so we can return more info to the client
    *         will contain the newly inserted TopicAssignment in the values map.
    *
    *         ie. responseDTO.values.get('TopicAssignments');
    *
    * @see ResponseDTO
    */
    @AuraEnabled
    public static ResponseDTO assignTopics(FeedItem fi, Network network, List<String> topicNames) {
        ResponseDTO dto = new ResponseDTO();

        List<Topic> topics = [select id, name, networkid from topic where name in :topicNames];

        if (!topics.isEmpty()) {
            dto.values.put('Topics', topics);
        } else {
            dto.message = 'Count not find topic records for topic strings passed=' + topicNames;
            dto.severity = 'warning';
            return dto;
        }
        List<TopicAssignment> tas = new List<TopicAssignment>();
        for(Topic t : topics) {
            TopicAssignment ta = new TopicAssignment();
            ta.TopicId = t.id;
            ta.EntityId = fi.id;
            ta.NetworkId = network.Id;
            tas.add(ta);
        }

        try {
            insert tas;
            dto.isSuccess = true;
            dto.values.put('TopicAssignments', tas);
        } catch (Exception e) {
            dto.severity = 'error';
            dto.message = e.getMessage();
        }
        return dto;
    }
    /**
     *
     *
     * @param parentId
     * @param caseId
     * @param fiId
     *
     * @return
     * @todo convert to return dto
     */
    @AuraEnabled
    public static ResponseDTO createFeedLike(Id fiId) {
        ResponseDTO dto = new ResponseDTO();
        try {
            FeedLike fl = new FeedLike();
            fl.FeedItemId = fiId;
            insert fl;
            dto.isSuccess = true;
            dto.values.put('FeedLike',fl);
        } catch(Exception e) {
            if(e.getMessage().contains('DUPLICATE_VALUE')) {
                dto.message = 'You have already Liked this question. You cannot Like it again!';
            } else {
                dto.message = e.getMessage();
            }
            dto.severity = 'error';
        }
        return dto;
    }
    /**
    * WORK IN PROGRESS.. meant to insert a new question ie. .feed comment
    *
    * @param fc
    * @param caseId
    * @param network
    * @param topic  optional.. send null if we don't want to assign a topic to the feeditem
    *
    * @return a ResponseDTO a generic wrapped object so we can return more info to the client
    *         will contain the newly inserted FeedComment in the values map.
    *
    * @see ResponseDTO
    */
    @AuraEnabled
    public static ResponseDTO createFeedItem(FeedItem fi, Id caseId, Network network) {

        ResponseDTO dto = new ResponseDTO();
        Boolean assignTopics = false;
        try {
            assignTopics = (Boolean)CustomSettingsUtls.getCarplsv20Settings(UserInfo.getUserId(), 'assign_topics__c');
        }  catch (Exception e) {
            dto.message += 'could not find custom setting assign_topics__c';
        }
        if (fi == null) {
            dto.message+= 'FeedItem passed is null we cant do shit with null';
            return dto;
        }
        if (network == null || network.Id == null) {
            fi.NetworkScope = '0DB1D000000001nWAA'; //IL-Aflan community
        } else {
            fi.NetworkScope = network.Id;
        }
        String pId = fi.ParentId;
        if(!pId.contains('0F9')) {
            fi.NetworkScope = 'AllNetworks';
           // fi.NetworkScope = NetworkScope.ALL_NETWORKS;
        }


        Case cse;
        try {
            cse = [select id, casenumber from case where id = :caseId];
        } catch (exception e) {
            system.debug(e);
        }
        if(fi.parentId.getSobjectType() == CollaborationGroup.getSObjectType()) {
            if (cse != null) {
                if (fi.Body == null) {
                    fi.Body = 'Case #' + cse.casenumber;
                } else {
                    fi.Body = 'Case #' + cse.casenumber + ' - ' + fi.Body;
                }
            }
        } else if (fi.parentId.getSobjectType() == Applied_Resource__c.getSObjectType()) {
            Applied_Resource__c ar;
            try {
                ar = [select id, name from applied_resource__c where id = :fi.parentId];
            } catch (exception e) {
                system.debug(e);
            }
            if (ar != null) {
                if (fi.Body == null) {
                    fi.Body = 'Applied Resource #' + ar.name;
                } else {
                    fi.Body = 'Applied Resource #' + ar.name + ' - ' + fi.Body;
                }
            }
        }
        fi.isRichText = true;


        try {
            fi.body = sanitizeHtml(fi.Body);
            insert fi;
            //@todo double check the blow!
            Carpls_Case_Question__c ccq = new Carpls_Case_Question__c();
            ccq.FeedItemId__c = fi.id;
            ccq.case__c = caseId;
            ccq.question_title__c = fi.Title;
            ccq.question_detail__c = fi.Body;
            if (network != null) {
                ccq.networkid__c = network.id;
                ccq.networkname__c = network.name;
            }
            fi = [select id, createdbyid from feeditem where id = :fi.id];
            if (fi.createdbyid.getSobjectType() == User.getSObjectType()) {
                ccq.author__c = fi.createdbyId;
            }
            ccq.Best_Answer__c = null;
            insert ccq;

            dto.isSuccess = true;
            dto.values.put('FeedItem', fi);
            dto.values.put('Carpls_Case_Question__c', ccq);
            if (assignTopics) {
                ccq = [
                        select id, FeedItemId__c, case__c, question_title__c, question_detail__c, networkid__c,
                                networkname__c, author__c, best_answer__c, problem_code__c, problem_category__c, practice_area__c
                        from Carpls_Case_Question__c ccq
                        where ccq.id = :ccq.id
                ];
                //---- CREATE TOPIC assignments if we can
                Set<String> topicNames = new Set<String>();
                if (ccq.practice_area__c != null) {
                    topicNames.add(ccq.practice_area__c);
                }
                if (ccq.problem_category__c != null) {
                    topicNames.add(ccq.practice_area__c);
                }
                if (ccq.problem_code__c != null) {
                    topicNames.add(ccq.problem_code__c);
                }

                if (!topicNames.isEmpty()) {
                    ResponseDTO topicDTO = assignTopics(fi, network, new List<String>(topicNames));
                    if (topicDTO.isSuccess) {
                        dto.values.put('TopicAssignments', (List<TopicAssignment>) topicDto.values.get('TopicAssignments'));
                    } else {
                        dto.message += topicDTO.message;
                        dto.severity = topicDTO.severity;
                        if (topicDTO.severity == 'error') {
                            dto.isSuccess = false;
                        }
                    }
                }
            }
        } catch (Exception e) {
            dto.message = e.getMessage() + 'stack=' + e.getStackTraceString();
            dto.severity = 'error';
        }

        return dto;
    }
    /**
     * WORK IN PROGRESS.. meant to insert a new answer ie. .feed comment
     *
     * @param fc
     *
     * @return a ResponseDTO a generic wrapped object so we can return more info to the client
     *         will contain the newly inserted FeedComment in the values map.
     *
     * @see ResponseDTO
     */
    @AuraEnabled
    public static ResponseDTO createFeedComment(FeedComment fc, String topic) {

        ResponseDTO dto = new ResponseDTO();

        if (fc == null) {
            dto.message = 'feedcomment passed is null we cant do shit with null';
            return dto;
        }
        if (fc.FeedItemId == null) {
            return dto;
        }
        fc.isRichText = true;

        try {
            fc.CommentBody = sanitizeHtml(fc.commentBody);

            insert fc;
            dto.isSuccess = true;
            dto.values.put('FeedComment', fc);

        } catch (Exception e) {
            dto.message = e.getMessage() + '.. html commentbody='+fc.CommentBody;
            dto.severity = 'error';
        }

        return dto;
    }


    /**
     * The FeedITem / FeedComment objects are pretty lame and doesn't support simple html tags that the lightning:inputrichtext editor is sending.
     * ie. it will throw a INVALID_MARKUP, Error while parsing Rich Text Content: Unsupported HTML tag or attribute encountered
     * on something simple such as <br>.
     *
     * @todo smarter parsing via reg ex..
     *
     * @param rteHtml
     */
   public static String sanitizeHtml(String rteHtml) {
        String sfdcSupportedHtml;
        if(rteHtml != null) {
            sfdcSupportedHtml = rteHtml;
            sfdcSupportedHtml = sfdcSupportedHtml.replace('<br>','<p>&nbsp;</p>');
        }
        return sfdcSupportedHtml;
    }


    /**
     *
     * @param fi a FeedItem
     *
     * @return a ResponseDTO a generic wrapped object so we can return more info to the client
     *         will contain the newly updated FeedItem in the values map.
     *
     * @see ResponseDTO
     */
    @AuraEnabled
    public static ResponseDTO updateFeedItem(FeedItem fi) {

        ResponseDTO dto = new ResponseDTO();

        if (fi == null || fi.id == null) {
            dto.message = 'feeditem or id passed is null we cant do shit with null';
            return dto;
        }
        try {
            update fi;
            dto.isSuccess = true;
            dto.values.put('FeedItem', fi);

        } catch (Exception e) {
            dto.message = e.getMessage();
            dto.severity = 'error';
        }

        return dto;
    }


    /**
     * Used initially to upate the best answer selected as we have to do that on our custom objects.
     * SFDC will not let us update that on the standard feeditem / feedcomment
     *
     * @param cca a Carpls_Case_Question__c to update.
     *
     * @return a ResponseDTO a generic wrapped object so we can return more info to the client
     *         will contain the newly updated Carpls_Case_Question__c  in the values map.
     *
     * @see ResponseDTO
     */
    @AuraEnabled
    public static ResponseDTO updateCarplsCaseQuestion(Carpls_Case_Question__c ccq) {

        ResponseDTO dto = new ResponseDTO();
        try {
            update ccq;
            dto.isSuccess = true;
            dto.values.put('Carpls_Case_Question__c', ccq);
        } catch (Exception e) {
            dto.message = 'error update carpls case q.. msg=' + e.getMessage() + '..stack=' + e.getStackTraceString();
            dto.severity = 'error';
        }
        return dto;
    }
}