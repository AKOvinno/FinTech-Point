-- Start of DDL Script for Package POWERIOV3.ACK_FILE_GLOBAL_VARS
-- Generated 08-Nov-2023 10:39:00 from POWERIOV3@(DESCRIPTION =(ADDRESS_LIST =(ADDRESS = (PROTOCOL = TCP)(HOST = 172.17.8.90)(PORT = 1530)))(CONNECT_DATA =(SERVICE_NAME = afcv3)))

CREATE OR REPLACE 
PACKAGE ack_file_global_vars    IS
-------------------------------------------------------------------------------------------------------------
--  Version         Date            Person          Comments
--  -------         --------        ----------      ---------------
--  V.1.0         28/08/2022        MRY (YAACOUBI)      Initial version
-------------------------------------------------------------------------------------------------------------
-- XML TAG INDEX
RECORD_NO                           CONSTANT     CHAR(1) :=  '1';
ENTITY_CODE                         CONSTANT     CHAR(1) :=  '2';
ENTITY_TYPE                         CONSTANT     CHAR(1) :=  '3';
PASSPORT_NO                         CONSTANT     CHAR(1) :=  '4';
COUNTRY_CODE                        CONSTANT     CHAR(1) :=  '5';
REF_NO                              CONSTANT     CHAR(1) :=  '6';
UNIQUE_REF_ID                       CONSTANT     CHAR(1) :=  '7';
DETAILS_MSG_DESC                    CONSTANT     CHAR(1) :=  '8';

-- Validation controls

NULL_VALUE                          CONSTANT     CHAR(1)  :=  '1';
BAD_VALUE                           CONSTANT     CHAR(1)  :=  '2';
NOT_NUMERIC                         CONSTANT     CHAR(1)  :=  '3';
NOT_DATE                            CONSTANT     CHAR(1)  :=  '4';
OTHER                               CONSTANT     CHAR(1)  :=  '5';

-- Processing_result
NOT_PROCESSED                   CONSTANT     CHAR(1) :=  'N';
REJECTED                        CONSTANT     CHAR(1) :=  'R';
PROCESSED                       CONSTANT     CHAR(1) :=  'P';

-- Report Result

NEW_ENT_MATCH                    CONSTANT    VARCHAR2(100) := 'New | Entity_Code matched';
NEW_ENT_NOT_MATCH                CONSTANT    VARCHAR2(100) := 'New | Entity_Code mismatched';
NEW_REF_ID_ENT_MATCH             CONSTANT    VARCHAR2(100) := 'New and existing Unique_Ref_ID | Entity_Code matched';
NEW_REF_ID_ENT_NOT_MATCH         CONSTANT    VARCHAR2(100) := 'New and existing Unique_Ref_ID | Entity_Code mismatched';
EXIST_REF_ID_ENT_MATCH           CONSTANT    VARCHAR2(100) := 'Existing and same Unique_Ref_ID | Entity_Code matched';
EXIST_DIF_REF_ID_ENT_MATCH       CONSTANT    VARCHAR2(100) := 'Existing and different Unique_Ref_ID | Entity_Code matched';
EXIST_SAME_REF_ID_ENT_MATCH      CONSTANT    VARCHAR2(100) := 'Existing and same Unique_Ref_ID | Entity_Code mismatched - Update entity_code';
EXIST_DIF_REF_ID_ENT_NOT_MATCH   CONSTANT    VARCHAR2(100) := 'Existing and different Unique_Ref_ID | Entity_Code mismatched';
CLIENT_NOT_EXIST                 CONSTANT    VARCHAR2(100) := 'Client not exist';
UNIQUE_REF_ID_NULL               CONSTANT    VARCHAR2(100) := 'Unique Ref ID is null';
UNIQUE_REF_ID_NOT_FOUND          CONSTANT    VARCHAR2(100) := 'New | Unique Ref ID is NOT FOUND';   -- AJHAR20231108


-- Disable control
ENABLE_CTRL                     CONSTANT     CHAR(1) :=  'N';


END ACK_FILE_GLOBAL_VARS ;
/

-- Grants for Package
GRANT EXECUTE ON ack_file_global_vars TO icps_power_cim
/


-- End of DDL Script for Package POWERIOV3.ACK_FILE_GLOBAL_VARS

