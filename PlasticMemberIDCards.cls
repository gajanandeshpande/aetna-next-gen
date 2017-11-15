global class PlasticMemberIDCards {
    webservice static String requestPlasticMemberIDCards(String membershipId) {
        Membership__c membership = [Select Id,Subscriber__r.CMM_External_Id__c,CMM_External_Id__c,Subscriber_CMM_ID__c,Individual__c 
                                    From Membership__c 
                                    Where Id =: membershipId Limit 1];
        
        EIEConnector connector = new EIEConnector();
        
        Fulfillment_Request_Log__c fulReq = new Fulfillment_Request_Log__c();        
        
        String cmmExternalId = String.isNotBlank(membership.Subscriber__r.CMM_External_Id__c) ? membership.Subscriber__r.CMM_External_Id__c
            : String.isNotBlank(membership.Subscriber_CMM_ID__c) ? membership.Subscriber_CMM_ID__c 
            : membership.CMM_External_Id__c;
            
        EIEEvent.createEventMembershipIDCard(connector, cmmExternalId, fulReq, false);
        
        //connector.finish();
        user u = [Select Id,firstName from user where id =: userInfo.getUserId() limit 1];
        u.firstName = u.firstName + '1';
        update u;
        
        if(fulReq.status__c != 'Processed') {
            return fulReq.Status_Detail__c;
        }
        else {
            fulReq.Type__c = 'ID Cards - Manual';
            fulReq.Status__c = fulReq.status__c;
            fulReq.Contact__c = membership.Individual__c; 
            insert fulReq;
            return 'ID Card Request is submitted successfully';
        } 
   }
}