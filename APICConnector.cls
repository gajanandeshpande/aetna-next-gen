public class APICConnector {
    public String appToken {get;set;}
    public Integer appTokenExpiresIn {get;set;}
    
    private HttpResponse createRequest(string endpoint, string method, string body, boolean useToken, string token) {
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod(method);
        
        Decimal timeOutInSec = APIC__c.getValues('apic_connection').Request_Timeout_in_sec__c;
        if(timeOutInSec != null){
            req.setTimeout(Integer.valueOf(timeOutInSec)*1000) ;
        }

        if (body != null) {
            req.setBody(body);
        }
        
        if (useToken) { 
            req.setHeader('X-IBM-Client-Id', + APIC__c.getValues('apic_connection').API_Key__c);            
            req.setHeader('Authorization','Bearer ' + token);
        }
        
        System.Debug('HEADER: Endpoint: '+ req.getEndpoint());
        System.Debug('HEADER: Method: '+ req.getMethod());
        System.debug('----');
        System.debug('REQUEST BODY: '+req.getBody());
        System.debug('REQUEST BODY Str: '+req.toString());
        HttpResponse res = h.send(req);
        return res;
    }
    
    @TestVisible private Map<String, Object> callAppTokenAPI() {
        HttpResponse res;
        String tokenEndPoint;
        try {           
            tokenEndPoint = APIC__c.getValues('apic_connection').Token_End_Point__c;
            String clientId = APIC__c.getValues('apic_connection').API_Key__c;
            String clientSecret = APIC__c.getValues('apic_connection').API_Secret__c;            
                        
        
            String reqBody ='grant_type=client_credentials&scope= Public NonPII' + '&client_id=' + clientId + '&client_secret=' + clientSecret ;
        
            res = createRequest(tokenEndPoint,'POST',reqBody,false,null);
        
            string response = res.getBody();
            system.debug(response);
        
            if (res.getStatusCode() == 200) {
                Map<String, Object> m = null;            
                m = (Map<String, Object>) System.JSON.deserializeUntyped(response);
                return m;
            }
            else {              
                System.debug('Error communicating with APIC: '+res.getStatusCode());
                System.debug('BODY: '+res.getBody());
                ApexPages.addmessage(new ApexPages.message(ApexPages.severity.WARNING,'There was an error processing the response from APIC.'));
                parseTokenStatus(res.getBody());                
            }            
        }
        catch(System.CalloutException e){
            system.debug(e.getMessage());
            system.debug(e.getStackTraceString());
            APILogActions.init('APIC Token'); 
            APILogActions.setURL(tokenEndPoint);
            APILogActions.setStatus(res.getStatusCode());
            APILogActions.setError(e.getStackTraceString());
            APILogActions.calculateTimeAndSave();              
            throw e;
        }
        catch (TokenException e) {
            system.debug(e.getMessage());
            system.debug(e.getStackTraceString());
            APILogActions.init('APIC Token');
            APILogActions.setURL(tokenEndPoint); 
            APILogActions.setStatus(res.getStatusCode());
            APILogActions.setError(e.getStackTraceString());
            APILogActions.calculateTimeAndSave();             
            throw e;
        } 
        catch (GenericAPICException e) {
            system.debug(e.getMessage());
            system.debug(e.getStackTraceString());
            APILogActions.init('APIC Token');
            APILogActions.setURL(tokenEndPoint); 
            APILogActions.setStatus(res.getStatusCode());
            APILogActions.setError(e.getStackTraceString());
            APILogActions.calculateTimeAndSave();             
            throw e;
        } 
        catch (Exception e) {
            system.debug('EXCEPTION IN APICConnector.callAppTokenAPI()');
            system.debug(e.getMessage());
            system.debug(e.getStackTraceString());
            APILogActions.init('APIC Token');
            APILogActions.setURL(tokenEndPoint); 
            APILogActions.setStatus(res.getStatusCode());
            APILogActions.setError(e.getStackTraceString());
            APILogActions.calculateTimeAndSave();             
            throw e;
        }
        return null;        
    }
   
   private boolean isAppTokenExpired() {
        DateTime tokenExpirationDate = APIC__c.getValues('apic_connection').Token_Last_Refreshed__c;
        Integer tokenExpirationSec = (Integer) APIC__c.getValues('apic_connection').Token_Expiration_Time_in_sec__c; 
       
        if(tokenExpirationDate == null && tokenExpirationSec == null) {
            return true;
        }
        else if(tokenExpirationDate.addSeconds(tokenExpirationSec) > DateTime.newInstance(System.now().date(), System.now().time()) ) {
            return false;
        }
        else {
            return true;
        }
    }
   
   @testVisible private String callDetailAPI(String endpoint, String method, String type) {       
        Boolean isUpdate = False; 
        HttpResponse res;             
        try {
           String token = getApplicationAPICToken();                     
           
           APILogActions.init(type);
           
           res = createRequest(endpoint,method,null,true,token);
           
           APILogActions.setURL(endpoint);
           
           string response = res.getBody();
           system.debug(response);
           
           APILogActions.setStatus(res.getStatusCode());

            if (res.getStatusCode() == 200) {
                APILogActions.calculateTimeAndSave();  
                return res.getBody();
            }
            else {
                System.debug('Error communicating with APIC: '+res.getStatusCode());
                System.debug('BODY: '+res.getBody());
                throw new GenericAPICException(' ' + res.getStatusCode());
            }
        }
        catch (TokenException e) {
            system.debug(e.getMessage());
            system.debug(e.getStackTraceString());
            APILogActions.setError(e.getStackTraceString());
            APILogActions.calculateTimeAndSave();            
            throw e;
        }
        catch (GenericAPICException e) {
            system.debug(e.getMessage());
            system.debug(e.getStackTraceString());
            APILogActions.setError(e.getStackTraceString());
            APILogActions.calculateTimeAndSave();            
            throw e;
        }  
        catch (Exception e) {
            system.debug('EXCEPTION IN EIEConnector.callEIEEndpoint()');
            system.debug(e.getMessage());
            system.debug(e.getStackTraceString());
            APILogActions.setError(e.getStackTraceString());
            APILogActions.calculateTimeAndSave();            
            throw e;
        }        
        return null;          
    }
   
    public String callMembershipAPI (String cmmId) {
        String apiUrl = APIC__c.getValues('apic_connection').Membership_End_Point__c+'/'+cmmId;
        return callDetailAPI(apiUrl, 'GET', 'Membership');
    }
    
    public String callMembershipPCPUpdateAPI (String cmmId,String subscriptionId, String memberId, String startDate, String primaryCarePhysicianNPI, String primaryCarePhysicianRoleId, String providerRoleTypeCode) {
        String apiUrl = APIC__c.getValues('apic_connection').Membership_End_Point__c+'/' + cmmId + '?' + 'subscriptionId=' + subscriptionId + '&' + 
                        'memberId=' + memberId + '&' +
                        'providerRoleTypeCode=' + providerRoleTypeCode + '&' + 
                        'startDate=' + startDate + '&' +
                        'primaryCarePhysicianNPI=' + primaryCarePhysicianNPI + '&' +
                        'primaryCarePhysicianRoleId=' + primaryCarePhysicianRoleId;
        return callDetailAPI(apiUrl, 'PUT', 'Membership');
    }
    
    public String callMemberCommunicationsAPI(String cmmId, String documentType, String documentSubType, String format, String reponseLevel, String listSelection) {
        String baseURL = String.format(APIC__c.getValues('apic_connection').Communications_Endpoint__c, new List<String>{cmmId});
        baseURL += '?documentType=' + documentType;
        baseURL += '&documentSubType=' + documentSubType;
        baseURL += '&format=' + format;
        baseURL += '&responseExpansionLevel=' + reponseLevel;
        baseURL += String.isNotBlank(listSelection) ? '&listSelection=' + listSelection : '';
        if(documentType == 'LETR') {        
            return callDetailAPI(baseURL, 'GET', 'NonEOBSearch');  
        }
        else {
            return callDetailAPI(baseURL, 'GET', 'EOBSearch');
        }          
    }
    
    public String callCommunicationContentsAPI(String contentID) {
        String baseURL = APIC__c.getValues('apic_connection').Communication_Contents_Endpoint__c + '/' + contentID;
        return callDetailAPI(baseURL, 'GET', 'EOBView');
    }

    public static void parseTokenStatus(String json){
        Map<String, Object> r = null;
        try{
            r = (Map<String, Object>) System.JSON.deserializeUntyped(json);
        }
        catch (Exception e) {
            throw new GenericAPICException('There was an error processing the response from Token APIC API');
        }
            
        if(r != null && r.containsKey('error_description')){
            String error_description = r.get('error_description') != null ? (String)r.get('error_description') : 'APIC Error';
            
            throw new GenericAPICException(error_description);
        }
        else {
            throw new GenericAPICException('There was an error processing the response from Token APIC API');
        }
    }

    public String getApplicationAPICToken() {
        Map<String, Object> m;
        String token;
        
        try {       
            if(isAppTokenExpired()) {
                m = callAppTokenAPI();
           
                if(m == Null) {
                    throw new GenericAPICException('There was an error in getting APIC Token');
                }
                else {
                    token = (String) m.get('access_token');
                    appToken = token;
                    appTokenExpiresIn = (Integer)m.get('expires_in');               
                }
            }
            else {
                token = APIC__c.getValues('apic_connection').Application_Token__c;
            }
        }
        catch(Exception e) {
            system.debug('EXCEPTION IN EIEConnector.getApplicationAPICToken()');
            system.debug(e.getMessage());
            system.debug(e.getStackTraceString());  
            throw e;            
        }
        
        return token;
    }

    public void finish() {
        Map<String, Object> m;
        String token;
        Boolean isUpdate = False;
        
        try {
            if(appToken != Null) {      
                APIC__c apicSettings = APIC__c.getInstance('apic_connection');
                apicSettings.Application_Token__c = appToken;
                apicSettings.Token_Expiration_Time_in_sec__c = appTokenExpiresIn;
                apicSettings.Token_Last_Refreshed__c = DateTime.newInstance(System.now().date(), System.now().time());
                update apicSettings; 
            }
        }
        catch(Exception e) {
            system.debug('EXCEPTION IN EIEConnector.finish()');
            system.debug(e.getMessage());
            system.debug(e.getStackTraceString());  
            throw e;            
        }       
    }   
                         
    public class GenericAPICException extends Exception {}                        
                
}