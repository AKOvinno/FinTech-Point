-- Start of DDL Script for Package Body POWERIOV3.PCRD_ACKNOWLEDGEMENT_FILE
-- Generated 21-Nov-2023 09:47:53 from POWERIOV3@(DESCRIPTION =(ADDRESS_LIST =(ADDRESS = (PROTOCOL = TCP)(HOST = 172.17.8.90)(PORT = 1530)))(CONNECT_DATA =(SERVICE_NAME = afcv3)))

CREATE OR REPLACE 
PACKAGE BODY pcrd_acknowledgement_file IS
-------------------------------------------------------------------------------------------------------------
--  VERSION         DATE            PERSON          COMMENTS
--  -------         --------        ----------      ---------------
--  V.1.0         28/08/2022        MRY (YAACOUBI)      INITIAL VERSION
--  V.1.1         28/05/2023        MRY (YAACOUBI)      MCIB : NEW FORMAT - CIM FINANCE
-------------------------------------------------------------------------------------------------------------

FUNCTION  LOAD_ACKNOWLEDGEMENT    (   P_BUSINESS_DATE           IN   DATE,
                                      P_TASK_NAME               IN   PCARD_TASKS.TASK_NAME%TYPE,
                                      P_PHYSICAL_FILE_NAME      IN   PCRD_FILE_PROCESSING.PHYSICAL_FILE_NAME%TYPE
                                  )
                                  RETURN PLS_INTEGER  IS

V_ENV_INFO_TRACE                    GLOBAL_VARS.ENV_INFO_TRACE_TYPE;
RETURN_STATUS                       PLS_INTEGER;
V_PCRD_FILE_PROCESSING_REC          PCRD_FILE_PROCESSING%ROWTYPE;

ERR_FILE_ALREADY_PROCESSED          CONSTANT PLS_INTEGER := 4551;
STATUS                              NUMBER;
ERR_INIT_COUNTERS                   CONSTANT PLS_INTEGER := 8033.; -- ERROR INITIALIZING BATCH COUNTERS
V_LOCAL_BANK_CODE                   BANK.BANK_CODE%TYPE;

P_COUNTER_1                     PCARD_TASKS.COUNTER_1%TYPE:=0;
P_COUNTER_2                     PCARD_TASKS.COUNTER_2%TYPE:=0;
P_COUNTER_3                     PCARD_TASKS.COUNTER_3%TYPE:=0;
P_COUNTER_4                     PCARD_TASKS.COUNTER_3%TYPE:=0;
P_AMOUNT_1                      PCARD_TASKS.AMOUNT_1%TYPE:=0;
P_AMOUNT_2                      PCARD_TASKS.AMOUNT_2%TYPE:=0;
P_AMOUNT_3                      PCARD_TASKS.AMOUNT_3%TYPE:=0;
P_AMOUNT_4                      PCARD_TASKS.AMOUNT_3%TYPE:=0;

V_ACK_FILE_BUFFER_REC               ACK_FILE_BUFFER%ROWTYPE;
V_ACK_FILE_HEADER_REC               ACK_FILE_HEADER%ROWTYPE;
V_ACK_FILE_DETAIL_REC               ACK_FILE_DETAIL%ROWTYPE;

V_IS_FILE_ALREADY_PROCESSED         PLS_INTEGER:=0;


BEGIN
    --------------------------------------------------------------------
    V_ENV_INFO_TRACE.BUSINESS_DATE  :=  P_BUSINESS_DATE;
    V_ENV_INFO_TRACE.USER_NAME      :=  GLOBAL_VARS.USER_NAME;
    V_ENV_INFO_TRACE.MODULE_CODE    :=  GLOBAL_VARS.ML_CREDIT_REVOLVING;
    V_ENV_INFO_TRACE.PACKAGE_NAME   :=  $$PLSQL_UNIT;
    V_ENV_INFO_TRACE.FUNCTION_NAME  :=  'LOAD_ACKNOWLEDGEMENT';
    V_ENV_INFO_TRACE.LANG           :=  GLOBAL_VARS.LANG;
    --------------------------------------------------------------------


    -----------------------------------------------------------------------------------------------------------------
    --  START INIT COUNTERS MANAGEMENT
    -----------------------------------------------------------------------------------------------------------------
    PCRD_ERRORS.TASK_NAME           := P_TASK_NAME;

    RETURN_STATUS   :=  PCRD_CAI_GENERAL_TOOLS_1.INIT_COUNTERS;
    IF  RETURN_STATUS   <>  DECLARATION_CST.OK
    THEN
        V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR REURNED BY PCRD_CAI_GENERAL_TOOLS_1.INIT_COUNTERS ';
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN( ERR_INIT_COUNTERS );
    END IF;

    -----------------------------------------------------------------------------------------------------------------
    --  SELECTING FROM BUFFER TABLE --> ACK_FILE_BUFFER
    -----------------------------------------------------------------------------------------------------------------

    BEGIN
        SELECT  *
        INTO    V_ACK_FILE_BUFFER_REC
        FROM    ACK_FILE_BUFFER
        WHERE ROWNUM = 1;
        --note
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'Note first line '||V_ACK_FILE_BUFFER_REC.FIRST_LINE ;
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
    EXCEPTION WHEN OTHERS
    THEN
        V_ENV_INFO_TRACE.ERROR_CODE     :=  GLOBAL_VARS_ERRORS.ERROR_SELECT;
        V_ENV_INFO_TRACE.PARAM1         :=  'ACK_FILE_BUFFER';
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR WHEN SELECTING FROM TABLE ACK_FILE_BUFFER   ! PLEASE CHECK FILE DATA ';
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN  DECLARATION_CST.ERROR;
    END;

    -----------------------------------------------------------------------------------------------------------------
    --  INSERT INTO HEADER TABLE --> ACK_FILE_HEADER
    -----------------------------------------------------------------------------------------------------------------
    RETURN_STATUS   := PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_HEADER(V_ACK_FILE_BUFFER_REC.SEQUENCE_NUMBER);

    IF  RETURN_STATUS <> DECLARATION_CST.OK
    THEN
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR WHEN CALLING PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_HEADER ! PLEASE CHECK FILE DATA : '
                                        ||  ' SEQUENCE NUMBER : ' || V_ACK_FILE_BUFFER_REC.SEQUENCE_NUMBER;
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN  RETURN_STATUS;
    END IF;

    -----------------------------------------------------------------------------------------------------------------
    --  INSERT INTO DETAIL TABLE --> ACK_FILE_DETAIL
    -----------------------------------------------------------------------------------------------------------------
     RETURN_STATUS   := PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_DETAIL(V_ACK_FILE_BUFFER_REC.SEQUENCE_NUMBER);

    IF  RETURN_STATUS <> DECLARATION_CST.OK
    THEN
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR WHEN CALLING PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_DETAIL ! PLEASE CHECK FILE DATA : '
                                        ||  ' SEQUENCE NUMBER : ' || V_ACK_FILE_BUFFER_REC.SEQUENCE_NUMBER;
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN  RETURN_STATUS;
    END IF;

    -----------------------------------------------------------------------------------------------------------------
    -- XML TAG VALIDATION --> ACK_FILE_HEADER
    -----------------------------------------------------------------------------------------------------------------
    RETURN_STATUS := PCRD_ACKNOWLEDGEMENT_FILE.PROC_ACK_FILE_PROC_HEADER ( P_BUSINESS_DATE,
                                                                            P_TASK_NAME,
                                                                           V_ACK_FILE_BUFFER_REC.SEQUENCE_NUMBER);
    IF  (RETURN_STATUS <> DECLARATION_CST.OK)
    THEN
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR WHEN CALLING PCRD_ACKNOWLEDGEMENT_FILE.PROC_ACK_FILE_PROC_HEADER';
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN  RETURN_STATUS;
    END IF;

    -----------------------------------------------------------------------------------------------------------------


    V_PCRD_FILE_PROCESSING_REC.PROCESSING_START_DATE    :=  SYSDATE;
    V_PCRD_FILE_PROCESSING_REC.RECORD_FLAG              :=  GLOBAL_VARS_4.BATCH_REC;
    V_PCRD_FILE_PROCESSING_REC.GLOBAL_REJECT_FILE       :=  GLOBAL_VARS.NO;
    V_PCRD_FILE_PROCESSING_REC.INTERNAL_FILE_NAME       :=  P_TASK_NAME;--'ACKNOWLEDGEMENT FILE';
    V_PCRD_FILE_PROCESSING_REC.PHYSICAL_FILE_NAME       :=  P_PHYSICAL_FILE_NAME;
    V_PCRD_FILE_PROCESSING_REC.SENDER_NAME              :=  P_TASK_NAME;

    V_PCRD_FILE_PROCESSING_REC.INTERNAL_CREATION_DATE   :=  P_BUSINESS_DATE;--TO_DATE(V_ACK_FILE_HEADER_REC.SUBMISSION_DATE, 'DD/MM/YYYY HH24:MI:SS');
    /**
    V_PCRD_FILE_PROCESSING_REC.FIRST_RECORD_FILE  :=        V_ACK_FILE_HEADER_REC.FILE_NAME
                                                          ||V_ACK_FILE_HEADER_REC.LOAD_FLAG
                                                          ||V_ACK_FILE_HEADER_REC.GROUP_
                                                          ||V_ACK_FILE_HEADER_REC.SUBMITTED_BY
                                                          ||V_ACK_FILE_HEADER_REC.SUBMISSION_DATE
                                                          ||V_ACK_FILE_HEADER_REC.LOAD_DATE
                                                          ||V_ACK_FILE_HEADER_REC.NO_OF_RECORDS
                                                          ||V_ACK_FILE_HEADER_REC.VALID_RECORDS;
                                                          */


    /*** MRY COMMENT : NO NEED TO USE THIS :
    RETURN_STATUS := PCRD_ACKNOWLEDGEMENT_FILE.CHECKS_FILE_PROCESSING ( V_PCRD_FILE_PROCESSING_REC );
    IF  RETURN_STATUS <> DECLARATION_CST.OK
    THEN
        IF  RETURN_STATUS =  DECLARATION_CST.NOK
        THEN
            V_ENV_INFO_TRACE.USER_MESSAGE   :=  'PCRD_ACKNOWLEDGEMENT_FILE.CHECKS_FILE_PROCESSING (ERR_FILE_ALREADY_PROCESSED) '
                                                    ||  'PHYSICAL FILE NAME : '      || V_PCRD_FILE_PROCESSING_REC.PHYSICAL_FILE_NAME
                                                    ||  ' INTERNAL FILE NAME : '     || V_PCRD_FILE_PROCESSING_REC.INTERNAL_FILE_NAME
                                                    ||  ' INTERNAL CREATION DATE : ' || V_PCRD_FILE_PROCESSING_REC.INTERNAL_CREATION_DATE;
            PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
            V_IS_FILE_ALREADY_PROCESSED :=1;
            --RETURN  ERR_FILE_ALREADY_PROCESSED;
        ELSE
            V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR WHEN CALLING PCRD_ACKNOWLEDGEMENT_FILE.CHECKS_FILE_PROCESSING '
                                                    ||  'PHYSICAL FILE NAME : '      || V_PCRD_FILE_PROCESSING_REC.PHYSICAL_FILE_NAME
                                                    ||  ' INTERNAL FILE NAME : '     || V_PCRD_FILE_PROCESSING_REC.INTERNAL_FILE_NAME
                                                    ||  ' INTERNAL CREATION DATE : ' || V_PCRD_FILE_PROCESSING_REC.INTERNAL_CREATION_DATE;
            PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
            RETURN  RETURN_STATUS;
        END IF;
    END IF;
    ******/

    RETURN_STATUS := PCRD_ACKNOWLEDGEMENT_FILE.PROC_ACK_FILE_PROC_DETAIL ( P_BUSINESS_DATE,
                                                                           P_TASK_NAME,
                                                                           V_PCRD_FILE_PROCESSING_REC.INTERNAL_FILE_NAME,
                                                                           V_PCRD_FILE_PROCESSING_REC.PHYSICAL_FILE_NAME,
                                                                           V_ACK_FILE_BUFFER_REC.SEQUENCE_NUMBER,
                                                                           V_IS_FILE_ALREADY_PROCESSED );
    IF  (RETURN_STATUS <> DECLARATION_CST.OK)
    THEN
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR WHEN CALLING PCRD_ACKNOWLEDGEMENT_FILE.PROC_ACK_FILE_PROC_DETAIL';
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN  RETURN_STATUS;
    END IF;

    RETURN_STATUS   :=  PCRD_GENERAL_TOOLS.GET_VALUE_FORM_GLOBALS_VAR  (    'LOCAL_BANK'        ,
                                                                            V_LOCAL_BANK_CODE   );

    IF RETURN_STATUS <> DECLARATION_CST.OK
    THEN
        V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR RETURNED BY PCRD_GENERAL_TOOLS.GET_VALUE_FORM_GLOBALS_VAR VAR =LOCAL_BANK';
        PCRD_GENERAL_TOOLS.PUT_TRACES  (V_ENV_INFO_TRACE, $$PLSQL_LINE );
        RETURN  RETURN_STATUS;
    END IF;

    V_PCRD_FILE_PROCESSING_REC.BANK_CODE                    :=  V_LOCAL_BANK_CODE;
    V_PCRD_FILE_PROCESSING_REC.SIGN_PURCHASE_PROCESS_FILE   :=  '-';
    V_PCRD_FILE_PROCESSING_REC.SIGN_REVERSAL_PROCESS_FILE   :=  '-';
    V_PCRD_FILE_PROCESSING_REC.SIGN_CANCELLED_PROCESS_FILE  :=  '-';
    V_PCRD_FILE_PROCESSING_REC.SIGN_BANK_MERCHANT_AMOUNT    :=  '-';
    V_PCRD_FILE_PROCESSING_REC.SIGN_MERCHANT_TRANS_AMOUNT   :=  '-';
    V_PCRD_FILE_PROCESSING_REC.LETTER_FLAG                  :=  'N';
    V_PCRD_FILE_PROCESSING_REC.PRINT_FLAG_LETTER            :=  'N';
    V_PCRD_FILE_PROCESSING_REC.PRINT_FLAG_REPORT            :=  'N';
    V_PCRD_FILE_PROCESSING_REC.FILE_TYPE                    :=  'N';

    V_PCRD_FILE_PROCESSING_REC.INTERNAL_SEQUENCE_FILE       := TO_CHAR(V_ACK_FILE_BUFFER_REC.SEQUENCE_NUMBER);

    -----------------------------------------------------------------------------------------------------------------

    BEGIN
        SELECT  TRANSACTION_FILE_SEQ.NEXTVAL
        INTO    V_PCRD_FILE_PROCESSING_REC.SEQUENCE_NUMBER
        FROM    DUAL;
    EXCEPTION WHEN OTHERS
    THEN
        V_ENV_INFO_TRACE.ERROR_CODE     := GLOBAL_VARS_ERRORS.UNDEFINED_SEQUENCE;
        V_ENV_INFO_TRACE.PARAM1         := 'TRANSACTION_FILE_SEQ';
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR WHEN SELECTING TRANSACTION_FILE_SEQ.NEXTVAL.';
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN  DECLARATION_CST.ERROR;
    END;

    RETURN_STATUS   :=  PCRD_CAI_GENERAL_TOOLS_1.CALCULATE_COUNTERS;
    IF  RETURN_STATUS   <>  DECLARATION_CST.OK
    THEN
        V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR WHEN CALCULATING COUNTERS ';
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN  RETURN_STATUS;
    END IF;

    V_PCRD_FILE_PROCESSING_REC.FILE_NUMBER_RECORDS          :=  V_ACK_FILE_HEADER_REC.NO_OF_RECORDS;
    V_PCRD_FILE_PROCESSING_REC.PROCESSING_NUMBER_RECORDS    :=  PCRD_CALL_EXTERNAL_TASK.P_PCARD_TASKS_COUNTERS.P_COUNTER_1;
    V_PCRD_FILE_PROCESSING_REC.NUMBER_VALID_RECORDS         :=  PCRD_CALL_EXTERNAL_TASK.P_PCARD_TASKS_COUNTERS.P_COUNTER_2;
    V_PCRD_FILE_PROCESSING_REC.NUMBER_REJECT_RECORDS        :=  PCRD_CALL_EXTERNAL_TASK.P_PCARD_TASKS_COUNTERS.P_COUNTER_3;
    V_PCRD_FILE_PROCESSING_REC.PROCESSING_END_DATE          :=  SYSDATE;

    V_PCRD_FILE_PROCESSING_REC.PROCESSING_STATUS            :=  GLOBAL_VARS_4.ENDED_SUCCESSFULLY;

    IF  PCRD_CALL_EXTERNAL_TASK.P_PCARD_TASKS_COUNTERS.P_COUNTER_1 = PCRD_CALL_EXTERNAL_TASK.P_PCARD_TASKS_COUNTERS.P_COUNTER_3
    AND PCRD_CALL_EXTERNAL_TASK.P_PCARD_TASKS_COUNTERS.P_COUNTER_3 <> 0
    THEN
        V_PCRD_FILE_PROCESSING_REC.PROCESSING_STATUS        :=  GLOBAL_VARS_4.ENDED_UNSUCCESSFULLY;
        V_PCRD_FILE_PROCESSING_REC.GLOBAL_REJECT_FILE       :=  GLOBAL_VARS.YES;
    END IF;

    IF  V_IS_FILE_ALREADY_PROCESSED = 1
    THEN
        V_PCRD_FILE_PROCESSING_REC.GLOBAL_REJECT_FILE        :=  GLOBAL_VARS.YES;
        V_PCRD_FILE_PROCESSING_REC.GLOBAL_REJECT_REASON      :=  'ERR_FILE_ALREADY_PROCESSED';
    END IF;

    RETURN_STATUS := PCRD_FILE_PROCESSING_TOOLS.PUT_PCRD_FILE_PROCESSING  (  V_PCRD_FILE_PROCESSING_REC  );
    IF  RETURN_STATUS <> DECLARATION_CST.OK
    THEN
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR WHEN CALLING PCRD_FILE_PROCESSING_TOOLS.PUT_PCRD_FILE_PROCESSING '
                                        ||  ' BANK CODE : '      || V_PCRD_FILE_PROCESSING_REC.BANK_CODE
                                        ||  ' FILE NAME : '      || V_PCRD_FILE_PROCESSING_REC.PHYSICAL_FILE_NAME
                                        ||  ' SEQUENC NUMBER : ' || V_PCRD_FILE_PROCESSING_REC.SEQUENCE_NUMBER;
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN  RETURN_STATUS;
    END IF;

    /* ARCHIVE TABLES */
    RETURN_STATUS   :=  PCRD_ACKNOWLEDGEMENT_FILE.ARCHIVE_TABLES;
    IF  RETURN_STATUS   <>  DECLARATION_CST.OK
    THEN
        V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR REURNED BY PCRD_ACKNOWLEDGEMENT_FILE.ARCHIVE_TABLES ';
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN( RETURN_STATUS );
    END IF;
    /* ARCHIVE TABLES */

    RETURN_STATUS   :=  PCRD_TRANS_CTRL_TOOLS_1.CALCULATE_RETURN_STATUS(PCRD_CALL_EXTERNAL_TASK.P_PCARD_TASKS_COUNTERS.P_COUNTER_1,
                                                                        PCRD_CALL_EXTERNAL_TASK.P_PCARD_TASKS_COUNTERS.P_COUNTER_3,
                                                                        STATUS);

    RETURN  STATUS;

EXCEPTION WHEN OTHERS
THEN
    V_ENV_INFO_TRACE.ERROR_CODE     :=  GLOBAL_VARS_ERRORS.ORACLE_ERROR;
    V_ENV_INFO_TRACE.USER_MESSAGE   := NULL;
    PCRD_GENERAL_TOOLS.PUT_TRACES   (V_ENV_INFO_TRACE,$$PLSQL_LINE);
    RETURN  DECLARATION_CST.ERROR;
END LOAD_ACKNOWLEDGEMENT;
-------------------------------------------------------------------------------------------------------------
FUNCTION    PUT_ACK_FILE_HEADER   ( P_SEQ_NUM               IN      ACK_FILE_BUFFER.SEQUENCE_NUMBER%TYPE)
                                          RETURN PLS_INTEGER  IS

BEGIN
        INSERT INTO ACK_FILE_HEADER(
            SELECT T.SEQUENCE_NUMBER,
               X.FILE_NAME,
               X.LOAD_FLAG,
               X.GROUP_,
               X.SUBMITTED_BY,
               X.SUBMISSION_DATE,
               X.LOAD_DATE,
               X.NO_OF_RECORDS,
               X.VALID_RECORDS,
               NULL,NULL,NULL,NULL

            FROM ACK_FILE_BUFFER T,
              XMLTABLE ('/MERGE/ACK' PASSING T.BUFFER COLUMNS
                                FILE_NAME VARCHAR2(50 BYTE) PATH '@file_name',
                                LOAD_FLAG VARCHAR2(50 BYTE) PATH '@load_flag',
                                GROUP_ VARCHAR2(50 BYTE) PATH 'GROUP',
                                SUBMITTED_BY VARCHAR2(50 BYTE) PATH 'SUBMITTED_BY',
                                SUBMISSION_DATE VARCHAR2(50 BYTE) PATH 'SUBMISSION_DATE',
                                LOAD_DATE VARCHAR2(50 BYTE) PATH 'LOAD_DATE',
                                NO_OF_RECORDS VARCHAR2(50 BYTE) PATH 'NO_OF_RECORDS',
                                VALID_RECORDS VARCHAR2(50 BYTE) PATH 'VALID_RECORDS') X
            WHERE T.SEQUENCE_NUMBER=P_SEQ_NUM
                                );
        COMMIT;
        RETURN(DECLARATION_CST.OK);

EXCEPTION
WHEN OTHERS THEN
    ROLLBACK;
    DECLARE
        V_ENV_INFO_TRACE        GLOBAL_VARS.ENV_INFO_TRACE_TYPE;
    BEGIN

       /* V_ENV_INFO_TRACE.ERROR_CODE   := 'PWC-00016';
        V_ENV_INFO_TRACE.PARAM1       := 'PCRD_FILE_PROCESSING';
*/
        V_ENV_INFO_TRACE.LANG           :=  GLOBAL_VARS.LANG;
        V_ENV_INFO_TRACE.USER_NAME      :=  GLOBAL_VARS.USER_NAME;
        V_ENV_INFO_TRACE.MODULE_CODE    :=  GLOBAL_VARS.ML_TRANSACTION;
        V_ENV_INFO_TRACE.PACKAGE_NAME   :=  $$PLSQL_UNIT;
        V_ENV_INFO_TRACE.FUNCTION_NAME  :=  'PUT_ACK_FILE_HEADER';
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR GLOBAL'||SUBSTR(SQLERRM,1,200);
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN (DECLARATION_CST.ERROR);
    END;
END PUT_ACK_FILE_HEADER;
-------------------------------------------------------------------------------------------------------------------------------
FUNCTION    ARCHIVE_TABLES
                                          RETURN PLS_INTEGER  IS


V_ENV_INFO_TRACE                GLOBAL_VARS.ENV_INFO_TRACE_TYPE;
RETURN_STATUS                   PLS_INTEGER;
BEGIN
--------------------------------------------------------------------
    --V_ENV_INFO_TRACE.BUSINESS_DATE  :=  P_BUSINESS_DATE;
    V_ENV_INFO_TRACE.USER_NAME      :=  GLOBAL_VARS.USER_NAME;
    V_ENV_INFO_TRACE.MODULE_CODE    :=  GLOBAL_VARS.ML_CREDIT_REVOLVING;
    V_ENV_INFO_TRACE.PACKAGE_NAME   :=  $$PLSQL_UNIT;
    V_ENV_INFO_TRACE.FUNCTION_NAME  :=  'ARCHIVE_TABLES';
    V_ENV_INFO_TRACE.LANG           :=  GLOBAL_VARS.LANG;
    --------------------------------------------------------------------.
        /* MH20012023 ADDED BACKUP/DELETE */
    INSERT INTO  ACK_FILE_BUFFER_HST SELECT * FROM ACK_FILE_BUFFER;
    DELETE FROM ACK_FILE_BUFFER;
    /* MH20012023 ADDED BACKUP/DELETE */


        /* MH20012023 ADDED BACKUP/DELETE */
    INSERT INTO  ACK_FILE_HEADER_HST SELECT * FROM ACK_FILE_HEADER;
    DELETE FROM ACK_FILE_HEADER;
    /* MH20012023 ADDED BACKUP/DELETE */

        /* MH20012023 ADDED BACKUP/DELETE */
    INSERT INTO  ACK_FILE_DETAIL_HST SELECT * FROM ACK_FILE_DETAIL;
    DELETE FROM ACK_FILE_DETAIL;
    /* MH20012023 ADDED BACKUP/DELETE

    INSERT INTO  ACK_FILE_SUCCESS_HST SELECT * FROM ACK_FILE_SUCCESS;  --Added Again Ajhar20231113
    DELETE FROM ACK_FILE_SUCCESS;

    INSERT INTO  ACK_FILE_REJECT_HST SELECT * FROM ACK_FILE_REJECT;   --Added Again Ajhar20231113
    DELETE FROM ACK_FILE_REJECT;

   --MH20012023 ADDED BACKUP/DELETE   */

 V_ENV_INFO_TRACE.USER_MESSAGE :=  'DELETION COMPLETED';
 PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN(DECLARATION_CST.OK);
EXCEPTION
WHEN
OTHERS THEN
 V_ENV_INFO_TRACE.USER_MESSAGE :=  'DELETION FAILED';
 PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN(DECLARATION_CST.NOK);

--EXCEPTION
--WHEN OTHERS THEN
    ROLLBACK;
    DECLARE
        V_ENV_INFO_TRACE        GLOBAL_VARS.ENV_INFO_TRACE_TYPE;
    BEGIN

        V_ENV_INFO_TRACE.LANG           :=  GLOBAL_VARS.LANG;
        V_ENV_INFO_TRACE.USER_NAME      :=  GLOBAL_VARS.USER_NAME;
        V_ENV_INFO_TRACE.MODULE_CODE    :=  GLOBAL_VARS.ML_TRANSACTION;
        V_ENV_INFO_TRACE.PACKAGE_NAME   :=  $$PLSQL_UNIT;
        V_ENV_INFO_TRACE.FUNCTION_NAME  :=  'ARCHIVE_TABLES';
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR GLOBAL'||SUBSTR(SQLERRM,1,200);
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN (DECLARATION_CST.ERROR);
    END;
END ARCHIVE_TABLES;
-------------------------------------------------------------------------------------------------------------------------------
/*START Ajhar20231113*/
-------------------------------------------------------------------------------------------------------------------------------
FUNCTION    ARCHIVE_SUCCESS_REJECT_TABLES
                                          RETURN PLS_INTEGER  IS


V_ENV_INFO_TRACE                GLOBAL_VARS.ENV_INFO_TRACE_TYPE;
RETURN_STATUS                   PLS_INTEGER;
BEGIN
--------------------------------------------------------------------
    --V_ENV_INFO_TRACE.BUSINESS_DATE  :=  P_BUSINESS_DATE;
    V_ENV_INFO_TRACE.USER_NAME      :=  GLOBAL_VARS.USER_NAME;
    V_ENV_INFO_TRACE.MODULE_CODE    :=  GLOBAL_VARS.ML_CREDIT_REVOLVING;
    V_ENV_INFO_TRACE.PACKAGE_NAME   :=  $$PLSQL_UNIT;
    V_ENV_INFO_TRACE.FUNCTION_NAME  :=  'ARCHIVE_SUCCESS_REJECT_TABLES';
    V_ENV_INFO_TRACE.LANG           :=  GLOBAL_VARS.LANG;
    --------------------------------------------------------------------.
    
    INSERT INTO  ACK_FILE_SUCCESS_HST SELECT * FROM ACK_FILE_SUCCESS;  --Added Again Ajhar20231113
    DELETE FROM ACK_FILE_SUCCESS;

    INSERT INTO  ACK_FILE_REJECT_HST SELECT * FROM ACK_FILE_REJECT;   --Added Again Ajhar20231113
    DELETE FROM ACK_FILE_REJECT;

    V_ENV_INFO_TRACE.USER_MESSAGE :=  'DELETION COMPLETED SUCCESS & REJECT_TABLES';
    PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN(DECLARATION_CST.OK);
EXCEPTION
WHEN
OTHERS THEN
   V_ENV_INFO_TRACE.USER_MESSAGE :=  'DELETION FAILED SUCCESS & REJECT_TABLES';
   PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN(DECLARATION_CST.NOK);

--EXCEPTION
--WHEN OTHERS THEN
    ROLLBACK;
    DECLARE
        V_ENV_INFO_TRACE        GLOBAL_VARS.ENV_INFO_TRACE_TYPE;
    BEGIN

        V_ENV_INFO_TRACE.LANG           :=  GLOBAL_VARS.LANG;
        V_ENV_INFO_TRACE.USER_NAME      :=  GLOBAL_VARS.USER_NAME;
        V_ENV_INFO_TRACE.MODULE_CODE    :=  GLOBAL_VARS.ML_TRANSACTION;
        V_ENV_INFO_TRACE.PACKAGE_NAME   :=  $$PLSQL_UNIT;
        V_ENV_INFO_TRACE.FUNCTION_NAME  :=  'ARCHIVE_SUCCESS_REJECT_TABLES';
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR GLOBAL'||SUBSTR(SQLERRM,1,200);
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN (DECLARATION_CST.ERROR);
    END;
END ARCHIVE_SUCCESS_REJECT_TABLES;
/*END Ajhar20231113*/
-------------------------------------------------------------------------------------------------------------------------------

FUNCTION    UPDATE_ACK_MAPPING_TABLE   (    P_REF_NO           IN ACK_FILE_DETAIL.REF_NO%TYPE,
                                            P_REC_NO           IN ACK_FILE_DETAIL.RECORD_NO%TYPE,
                                            P_ENTITY_CODE      IN ACK_FILE_DETAIL.ENTITY_CODE%TYPE,
                                            P_FILE_NAME        IN ACK_FILE_HEADER.FILE_NAME%TYPE,
                                            P_SEQ_NO           IN ACK_FILE_DETAIL.SEQUENCE_NUMBER%TYPE
                                        )
                                          RETURN PLS_INTEGER  IS


V_ENV_INFO_TRACE                GLOBAL_VARS.ENV_INFO_TRACE_TYPE;
RETURN_STATUS                   PLS_INTEGER;
BEGIN
--------------------------------------------------------------------
    --V_ENV_INFO_TRACE.BUSINESS_DATE  :=  P_BUSINESS_DATE;
    V_ENV_INFO_TRACE.USER_NAME      :=  GLOBAL_VARS.USER_NAME;
    V_ENV_INFO_TRACE.MODULE_CODE    :=  GLOBAL_VARS.ML_CREDIT_REVOLVING;
    V_ENV_INFO_TRACE.PACKAGE_NAME   :=  $$PLSQL_UNIT;
    V_ENV_INFO_TRACE.FUNCTION_NAME  :=  'UPDATE_ACK_MAPPING_TABLE';
    V_ENV_INFO_TRACE.LANG           :=  GLOBAL_VARS.LANG;
    --------------------------------------------------------------------.
    /*UPDATE ACK_MAPPING_TABLE(SELECT T.SEQUENCE_NUMBER,
               RECORD_NO,
               ENTITY_CODE,
               ENTITY_TYPE,
               NULL,NULL,
               REF_NO,
               UNIQUE_REF_ID,
               NULL,NULL,
               NULL,NULL,NULL,NULL
          FROM ACK_FILE_DETAIL T
          WHERE T.RECORD_NO=P_REC_NO
            );
        COMMIT; */
        UPDATE ACK_MAPPING_TABLE SET ENTITY_CODE = P_ENTITY_CODE
        WHERE REF_NO = P_REF_NO
        AND REF_NO--RECORD_NO
        IN
        (SELECT REF_NO--RECORD_NO
        FROM ACK_FILE_DETAIL T
        WHERE T.RECORD_NO=P_REC_NO
        AND INTERNAL_FILE_NAME = P_FILE_NAME
        AND SEQUENCE_NUMBER = P_SEQ_NO
        AND ROWNUM=1
        );
        COMMIT;
 V_ENV_INFO_TRACE.USER_MESSAGE :=  'UPDATE COMPLETED: ' || P_REC_NO ;-- || ACK_FILE_DETAIL.RECORD_NO;
 PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN(DECLARATION_CST.OK);
EXCEPTION
WHEN
OTHERS THEN
 V_ENV_INFO_TRACE.USER_MESSAGE :=  'UPDATE FAILED: ' || P_REC_NO ;
 PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN(DECLARATION_CST.NOK);

--EXCEPTION
--WHEN OTHERS THEN
    ROLLBACK;
    DECLARE
        V_ENV_INFO_TRACE        GLOBAL_VARS.ENV_INFO_TRACE_TYPE;
    BEGIN

        V_ENV_INFO_TRACE.LANG           :=  GLOBAL_VARS.LANG;
        V_ENV_INFO_TRACE.USER_NAME      :=  GLOBAL_VARS.USER_NAME;
        V_ENV_INFO_TRACE.MODULE_CODE    :=  GLOBAL_VARS.ML_TRANSACTION;
        V_ENV_INFO_TRACE.PACKAGE_NAME   :=  $$PLSQL_UNIT;
        V_ENV_INFO_TRACE.FUNCTION_NAME  :=  'UPDATE_ACK_MAPPING_TABLE';
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR GLOBAL'||SUBSTR(SQLERRM,1,200);
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN (DECLARATION_CST.ERROR);
    END;
END UPDATE_ACK_MAPPING_TABLE;
-------------------------------------------------------------------------------------------------------------
FUNCTION    PUT_ACK_FILE_DETAIL   ( P_SEQ_NUM               IN      ACK_FILE_BUFFER.SEQUENCE_NUMBER%TYPE)
                                          RETURN PLS_INTEGER  IS

BEGIN
        INSERT INTO ACK_FILE_DETAIL(
          /*SELECT T.SEQUENCE_NUMBER,
               X.LOG,
               X.ENTITY_CODE,
               X.ENTITY_TYPE,
               X.PASSPORT_NO,
               X.COUNTRY_CODE,
               X.REF_NO,
               DECODE(TRIM(X.UNIQUE_REF_ID),'NOT FOUND',NULL,TRIM(X.UNIQUE_REF_ID)),
               --X.UNIQUE_REF_ID,
               NULL,--X.DETAILS_MSG_DESC,
               NULL,INTERNAL_FILE_NAME,NULL,NULL,
               NULL,NULL,NULL,NULL
          FROM ACK_FILE_BUFFER T,
              XMLTABLE ('FOR $I IN /MERGE/ACK
                           , $J IN $I/LOG
                           , $E IN $J/DETAILS
                             RETURN ELEMENT R {
               $I/@FILE_NAME,
               $J/@RECORD_NO ,
               $J/ENTITY_CODE ,
               $J/ENTITY_TYPE,
               $J/PASSPORT_NO ,
               $J/COUNTRY_CODE,
               $J/REF_NO,
               $J/UNIQUE_REF_ID,
               $E/MSG_DESC

        }'
                    PASSING T.BUFFER
                    COLUMNS

                            LOG VARCHAR2(50 BYTE) PATH '@RECORD_NO',
                            ENTITY_CODE VARCHAR2(50 BYTE) PATH 'ENTITY_CODE',
                            ENTITY_TYPE VARCHAR2(50 BYTE) PATH 'ENTITY_TYPE',
                            PASSPORT_NO VARCHAR2(50 BYTE) PATH 'PASSPORT_NO',
                            COUNTRY_CODE VARCHAR2(50 BYTE) PATH 'COUNTRY_CODE',
                            REF_NO VARCHAR2(50 BYTE) PATH 'REF_NO',
                            UNIQUE_REF_ID VARCHAR2(50 BYTE) PATH 'UNIQUE_REF_ID',
                            --DETAILS_MSG_DESC VARCHAR2(100 BYTE) PATH 'MSG_DESC',
                            INTERNAL_FILE_NAME VARCHAR2(50 BYTE) PATH '@FILE_NAME') X
          WHERE T.SEQUENCE_NUMBER=P_SEQ_NUM*/
          SELECT t.sequence_number,
               x.record_no,
               x.entity_code,
               x.entity_type,
               x.passport_no,
               x.country_code,
               x.ref_no,
               x.unique_ref_id,
               --x.details_msg_desc,
               NULL,
               null,internal_file_name,null,null,
               null,null,null,null--,null
          FROM ack_file_buffer t,
              XMLTABLE ('for $i in /MERGE/ACK
                           , $j in $i/LOG
                           , $e in $j/DETAILS
                             return element r {
               $i/@file_name,
               $j/@record_no ,
               $j/ENTITY_CODE ,
               $j/ENTITY_TYPE,
               $j/PASSPORT_NO ,
               $j/COUNTRY_CODE,
               $j/REF_NO,
               $j/UNIQUE_REF_ID,
               $e/MSG_DESC

        }'
                    PASSING t.buffer
                    COLUMNS

                            record_no VARCHAR2(50 BYTE) PATH '@record_no',
                            entity_code VARCHAR2(50 BYTE) PATH 'ENTITY_CODE',
                            entity_type VARCHAR2(50 BYTE) PATH 'ENTITY_TYPE',
                            passport_no VARCHAR2(50 BYTE) PATH 'PASSPORT_NO',
                            country_code VARCHAR2(50 BYTE) PATH 'COUNTRY_CODE',
                            ref_no VARCHAR2(50 BYTE) PATH 'REF_NO',
                            unique_ref_id VARCHAR2(50 BYTE) PATH 'UNIQUE_REF_ID',
                            --details_msg_desc VARCHAR2(100 BYTE) PATH 'MSG_DESC',
                            internal_file_name VARCHAR2(50 BYTE) PATH '@file_name') x
          where t.sequence_number=p_seq_num

            );
        COMMIT;
        RETURN(DECLARATION_CST.OK);

EXCEPTION
WHEN OTHERS THEN
    ROLLBACK;
    DECLARE
        V_ENV_INFO_TRACE        GLOBAL_VARS.ENV_INFO_TRACE_TYPE;
    BEGIN

       /* V_ENV_INFO_TRACE.ERROR_CODE   := 'PWC-00016';
        V_ENV_INFO_TRACE.PARAM1       := 'PCRD_FILE_PROCESSING';
*/
        V_ENV_INFO_TRACE.LANG           :=  GLOBAL_VARS.LANG;
        V_ENV_INFO_TRACE.USER_NAME      :=  GLOBAL_VARS.USER_NAME;
        V_ENV_INFO_TRACE.MODULE_CODE    :=  GLOBAL_VARS.ML_TRANSACTION;
        V_ENV_INFO_TRACE.PACKAGE_NAME   :=  $$PLSQL_UNIT;
        V_ENV_INFO_TRACE.FUNCTION_NAME  :=  'PUT_ACK_FILE_DETAIL';
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR GLOBAL'||SUBSTR(SQLERRM,1,200);
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN (DECLARATION_CST.ERROR);
    END;
END PUT_ACK_FILE_DETAIL;
-------------------------------------------------------------------------------------------------------------------------------
FUNCTION    PUT_ACK_MAPPING_TABLE   ( --P_SEQ_NUM               IN      ACK_FILE_BUFFER.SEQUENCE_NUMBER%TYPE
                                      --P_REC_NO           IN ACK_FILE_DETAIL.RECORD_NO%TYPE
                                      P_REC_NO           IN ACK_MAPPING_TABLE.RECORD_NO%TYPE,
                                      P_FILE_NAME        IN ACK_FILE_HEADER.FILE_NAME%TYPE,
                                      P_SEQ_NO           IN ACK_FILE_DETAIL.SEQUENCE_NUMBER%TYPE
                                    )
                                          RETURN PLS_INTEGER  IS


V_ENV_INFO_TRACE                GLOBAL_VARS.ENV_INFO_TRACE_TYPE;
RETURN_STATUS                   PLS_INTEGER;
BEGIN
--------------------------------------------------------------------
    --V_ENV_INFO_TRACE.BUSINESS_DATE  :=  P_BUSINESS_DATE;
    V_ENV_INFO_TRACE.USER_NAME      :=  GLOBAL_VARS.USER_NAME;
    V_ENV_INFO_TRACE.MODULE_CODE    :=  GLOBAL_VARS.ML_CREDIT_REVOLVING;
    V_ENV_INFO_TRACE.PACKAGE_NAME   :=  $$PLSQL_UNIT;
    V_ENV_INFO_TRACE.FUNCTION_NAME  :=  'PROCESS_ACK_FILE_DETAIL_TABLE';
    V_ENV_INFO_TRACE.LANG           :=  GLOBAL_VARS.LANG;
    --------------------------------------------------------------------.
    /* MH20012023 ADDED BACKUP/DELETE */
    --INSERT INTO  ACK_FILE_DETAIL_HST SELECT * FROM ACK_FILE_DETAIL;
    --DELETE FROM ACK_FILE_DETAIL;
    /* MH20012023 ADDED BACKUP/DELETE */
        INSERT INTO ACK_MAPPING_TABLE(
          SELECT T.SEQUENCE_NUMBER,
               RECORD_NO,
               DECODE(ENTITY_TYPE,'C', 'C'||ENTITY_CODE, 'P','P'||ENTITY_CODE, ENTITY_CODE),
               ENTITY_TYPE,
               NULL,NULL,
               REF_NO,
               DECODE(TRIM(UNIQUE_REF_ID),'NOT FOUND',NULL,TRIM(UNIQUE_REF_ID)),
               --UNIQUE_REF_ID,
               INTERNAL_FILE_NAME,
               NULL,NULL,
               NULL,NULL,NULL,NULL
          FROM ACK_FILE_DETAIL T
          WHERE T.RECORD_NO=P_REC_NO
          AND T.SEQUENCE_NUMBER = P_SEQ_NO
          AND T.INTERNAL_FILE_NAME = P_FILE_NAME
            );
        COMMIT;
 V_ENV_INFO_TRACE.USER_MESSAGE :=  'INSERT COMPLETED: ' || P_REC_NO ;-- || ACK_FILE_DETAIL.RECORD_NO;
 PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN(DECLARATION_CST.OK);
EXCEPTION
WHEN
OTHERS THEN
 V_ENV_INFO_TRACE.USER_MESSAGE :=  'INSERT FAILED: ' || P_REC_NO ;
 PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN(DECLARATION_CST.NOK);

--EXCEPTION
--WHEN OTHERS THEN
    ROLLBACK;
    DECLARE
        V_ENV_INFO_TRACE                GLOBAL_VARS.ENV_INFO_TRACE_TYPE;
    BEGIN

        V_ENV_INFO_TRACE.LANG           :=  GLOBAL_VARS.LANG;
        V_ENV_INFO_TRACE.USER_NAME      :=  GLOBAL_VARS.USER_NAME;
        V_ENV_INFO_TRACE.MODULE_CODE    :=  GLOBAL_VARS.ML_TRANSACTION;
        V_ENV_INFO_TRACE.PACKAGE_NAME   :=  $$PLSQL_UNIT;
        V_ENV_INFO_TRACE.FUNCTION_NAME  :=  'PUT_ACK_MAPPING_TABLE';
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR GLOBAL'||SUBSTR(SQLERRM,1,200);
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN (DECLARATION_CST.ERROR);
    END;
END PUT_ACK_MAPPING_TABLE;
-------------------------------------------------------------------------------------------------------------------------------

FUNCTION    PUT_ACK_FILE_SUCCESS   (        P_REC_NO           IN ACK_MAPPING_TABLE.RECORD_NO%TYPE,
                                            P_FILE_NAME        IN ACK_FILE_HEADER.FILE_NAME%TYPE,
                                            P_SEQ_NO           IN ACK_FILE_DETAIL.SEQUENCE_NUMBER%TYPE,
                                           P_STATUS_MSG        IN VARCHAR2 )
                                            RETURN PLS_INTEGER  IS


V_ENV_INFO_TRACE                GLOBAL_VARS.ENV_INFO_TRACE_TYPE;
RETURN_STATUS                   PLS_INTEGER;
V_SHADOW_ACCOUNT_NBR            SHADOW_ACCOUNT%ROWTYPE;
BEGIN
--------------------------------------------------------------------
    --V_ENV_INFO_TRACE.BUSINESS_DATE  :=  P_BUSINESS_DATE;
    V_ENV_INFO_TRACE.USER_NAME      :=  GLOBAL_VARS.USER_NAME;
    V_ENV_INFO_TRACE.MODULE_CODE    :=  GLOBAL_VARS.ML_CREDIT_REVOLVING;
    V_ENV_INFO_TRACE.PACKAGE_NAME   :=  $$PLSQL_UNIT;
    V_ENV_INFO_TRACE.FUNCTION_NAME  :=  'PUT_ACK_FILE_SUCCESS';
    V_ENV_INFO_TRACE.LANG           :=  GLOBAL_VARS.LANG;
    --------------------------------------------------------------------.
    /* MH20012023 ADDED BACKUP/DELETE */
    --INSERT INTO  ACK_FILE_DETAIL_HST SELECT * FROM ACK_FILE_DETAIL;
    --DELETE FROM ACK_FILE_DETAIL;
    /* MH20012023 ADDED BACKUP/DELETE */
        INSERT INTO ACK_FILE_SUCCESS(
          SELECT T.SEQUENCE_NUMBER,
               RECORD_NO,
               DECODE(ENTITY_TYPE,'C', 'C'||ENTITY_CODE, 'P','P'||ENTITY_CODE, ENTITY_CODE),
               ENTITY_TYPE,
               NULL,NULL,
               REF_NO,
               UNIQUE_REF_ID,
               NULL,NULL,
               INTERNAL_FILE_NAME,NULL,
               NULL,NULL,
               NULL,NULL,NULL
          FROM ACK_FILE_DETAIL T
          WHERE T.RECORD_NO=P_REC_NO
          AND T.SEQUENCE_NUMBER = P_SEQ_NO
          AND T.INTERNAL_FILE_NAME = P_FILE_NAME
        --AND DETAILS_MSG_DESC = P_STATUS_MSG
        );


        COMMIT;

--------------------------------------------------------------------
    --V_ENV_INFO_TRACE.BUSINESS_DATE  :=  P_BUSINESS_DATE;
    V_ENV_INFO_TRACE.USER_NAME      :=  GLOBAL_VARS.USER_NAME;
    V_ENV_INFO_TRACE.MODULE_CODE    :=  GLOBAL_VARS.ML_CREDIT_REVOLVING;
    V_ENV_INFO_TRACE.PACKAGE_NAME   :=  $$PLSQL_UNIT;
    V_ENV_INFO_TRACE.FUNCTION_NAME  :=  'PUT_ACK_FILE_SUCCESS';
    V_ENV_INFO_TRACE.LANG           :=  GLOBAL_VARS.LANG;
    --------------------------------------------------------------------.
    BEGIN

        UPDATE ACK_FILE_SUCCESS SET DETAILS_MSG_DESC = P_STATUS_MSG
        WHERE RECORD_NO = P_REC_NO
        AND INTERNAL_FILE_NAME = P_FILE_NAME
        AND SEQUENCE_NUMBER = P_SEQ_NO;
        COMMIT;

    EXCEPTION
    WHEN OTHERS THEN

        V_ENV_INFO_TRACE.USER_MESSAGE :=  'UPDATE FAILED INTO ACK_FILE_SUCCESS: ' || P_REC_NO || ' P_SEQ_NO: '|| P_SEQ_NO || ' P_FILE_NAME: ' ||P_FILE_NAME || ' P_STATUS_MSG: ' || P_STATUS_MSG;
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
    RETURN(DECLARATION_CST.NOK);

    END;

 V_ENV_INFO_TRACE.USER_MESSAGE :=  'INSERT COMPLETED: ' || P_REC_NO || ' P_SEQ_NO: '|| P_SEQ_NO || ' P_FILE_NAME: ' ||P_FILE_NAME;
 PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN(DECLARATION_CST.OK);

EXCEPTION
WHEN
OTHERS THEN
 V_ENV_INFO_TRACE.USER_MESSAGE :=  'INSERT FAILED: ' || P_REC_NO ||' P_FILE_NAME: ' ||P_FILE_NAME ;
 PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN(DECLARATION_CST.NOK);

--EXCEPTION
--WHEN OTHERS THEN
    ROLLBACK;
    DECLARE
        V_ENV_INFO_TRACE        GLOBAL_VARS.ENV_INFO_TRACE_TYPE;
    BEGIN

        V_ENV_INFO_TRACE.LANG           :=  GLOBAL_VARS.LANG;
        V_ENV_INFO_TRACE.USER_NAME      :=  GLOBAL_VARS.USER_NAME;
        V_ENV_INFO_TRACE.MODULE_CODE    :=  GLOBAL_VARS.ML_TRANSACTION;
        V_ENV_INFO_TRACE.PACKAGE_NAME   :=  $$PLSQL_UNIT;
        V_ENV_INFO_TRACE.FUNCTION_NAME  :=  'PUT_ACK_MAPPING_TABLE';
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR GLOBAL'||SUBSTR(SQLERRM,1,200);
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN (DECLARATION_CST.ERROR);

    END;
END PUT_ACK_FILE_SUCCESS;

-------------------------------------------------------------------------------------------------------------------------------

FUNCTION    PUT_ACK_FILE_REJECT   (     P_REC_NO           IN ACK_MAPPING_TABLE.RECORD_NO%TYPE,
                                        P_FILE_NAME        IN ACK_FILE_HEADER.FILE_NAME%TYPE,
                                        P_SEQ_NO           IN ACK_FILE_DETAIL.SEQUENCE_NUMBER%TYPE,
                                        P_STATUS_MSG        IN VARCHAR2 )
                                            RETURN PLS_INTEGER  IS


V_ENV_INFO_TRACE                GLOBAL_VARS.ENV_INFO_TRACE_TYPE;
RETURN_STATUS                   PLS_INTEGER;
BEGIN
--------------------------------------------------------------------
    --V_ENV_INFO_TRACE.BUSINESS_DATE  :=  P_BUSINESS_DATE;
    V_ENV_INFO_TRACE.USER_NAME      :=  GLOBAL_VARS.USER_NAME;
    V_ENV_INFO_TRACE.MODULE_CODE    :=  GLOBAL_VARS.ML_CREDIT_REVOLVING;
    V_ENV_INFO_TRACE.PACKAGE_NAME   :=  $$PLSQL_UNIT;
    V_ENV_INFO_TRACE.FUNCTION_NAME  :=  'PUT_ACK_FILE_REJECT';
    V_ENV_INFO_TRACE.LANG           :=  GLOBAL_VARS.LANG;
    --------------------------------------------------------------------.
    /* MH20012023 ADDED BACKUP/DELETE */
    --INSERT INTO  ACK_FILE_DETAIL_HST SELECT * FROM ACK_FILE_DETAIL;
    --DELETE FROM ACK_FILE_DETAIL;
    /* MH20012023 ADDED BACKUP/DELETE */
        INSERT INTO ACK_FILE_REJECT(
          SELECT T.SEQUENCE_NUMBER,
               RECORD_NO,
               DECODE(ENTITY_TYPE,'C', 'C'||ENTITY_CODE, 'P','P'||ENTITY_CODE, ENTITY_CODE),
               ENTITY_TYPE,
               NULL,NULL,
               REF_NO,
               UNIQUE_REF_ID,  --ques3 --DECODE(TRIM(UNIQUE_REF_ID),'NOT FOUND',NULL,TRIM(UNIQUE_REF_ID)) 
               NULL,NULL,
               INTERNAL_FILE_NAME,NULL,
               NULL,NULL,
               NULL,NULL,NULL
          FROM ACK_FILE_DETAIL T
          WHERE T.RECORD_NO=P_REC_NO
          AND T.SEQUENCE_NUMBER = P_SEQ_NO
          AND T.INTERNAL_FILE_NAME = P_FILE_NAME

            );
        COMMIT;
        UPDATE ACK_FILE_REJECT SET DETAILS_MSG_DESC = P_STATUS_MSG WHERE RECORD_NO = P_REC_NO AND INTERNAL_FILE_NAME = P_FILE_NAME AND SEQUENCE_NUMBER = P_SEQ_NO;
        COMMIT;

 V_ENV_INFO_TRACE.USER_MESSAGE :=  'INSERT IN PUT_ACK_FILE_REJECT COMPLETED: ' || P_REC_NO ;-- || ACK_FILE_DETAIL.RECORD_NO;
 PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN(DECLARATION_CST.OK);
EXCEPTION
WHEN
OTHERS THEN
 V_ENV_INFO_TRACE.USER_MESSAGE :=  'INSERT FAILED: ' || P_REC_NO ;
 PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN(DECLARATION_CST.NOK);

--EXCEPTION
--WHEN OTHERS THEN
    ROLLBACK;
    DECLARE
        V_ENV_INFO_TRACE        GLOBAL_VARS.ENV_INFO_TRACE_TYPE;
    BEGIN

        V_ENV_INFO_TRACE.LANG           :=  GLOBAL_VARS.LANG;
        V_ENV_INFO_TRACE.USER_NAME      :=  GLOBAL_VARS.USER_NAME;
        V_ENV_INFO_TRACE.MODULE_CODE    :=  GLOBAL_VARS.ML_TRANSACTION;
        V_ENV_INFO_TRACE.PACKAGE_NAME   :=  $$PLSQL_UNIT;
        V_ENV_INFO_TRACE.FUNCTION_NAME  :=  'PUT_ACK_MAPPING_TABLE';
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR GLOBAL'||SUBSTR(SQLERRM,1,200);
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN (DECLARATION_CST.ERROR);
    END;
END PUT_ACK_FILE_REJECT;
-------------------------------------------------------------------------------------------------------------------------------
FUNCTION    CHECKS_FILE_PROCESSING     ( P_PCRD_FILE_PROCESSING_REC               IN      PCRD_FILE_PROCESSING%ROWTYPE)
                                        RETURN PLS_INTEGER  IS


V_ENV_INFO_TRACE        GLOBAL_VARS.ENV_INFO_TRACE_TYPE;
V_NBR_RECORD            PLS_INTEGER;
RETURN_STATUS           PLS_INTEGER;
BEGIN
        V_ENV_INFO_TRACE.LANG           :=  GLOBAL_VARS.LANG;
        V_ENV_INFO_TRACE.USER_NAME      :=  GLOBAL_VARS.USER_NAME;
        V_ENV_INFO_TRACE.MODULE_CODE    :=  GLOBAL_VARS.ML_TRANSACTION;
        V_ENV_INFO_TRACE.PACKAGE_NAME   :=  $$PLSQL_UNIT;
        V_ENV_INFO_TRACE.FUNCTION_NAME  :=  'CHECKS_FILE_PROCESSING';
    BEGIN
        SELECT  COUNT(*)
        INTO    V_NBR_RECORD
        FROM    PCRD_FILE_PROCESSING
        WHERE
                --PHYSICAL_FILE_NAME                                          = P_PCRD_FILE_PROCESSING_REC.PHYSICAL_FILE_NAME AND
             NVL(INTERNAL_FILE_NAME       ,'X')                          = NVL(P_PCRD_FILE_PROCESSING_REC.INTERNAL_FILE_NAME       ,'X')
          --AND   NVL(INTERNAL_SEQUENCE_FILE   ,'X')                          = NVL(P_PCRD_FILE_PROCESSING_REC.INTERNAL_SEQUENCE_FILE   ,'X')
          --AND   NVL(INTERNAL_CREATION_DATE   ,TO_DATE('01/01/0001 00:00:00','DD/MM/YYYY HH24:MI:SS'))   = NVL(P_PCRD_FILE_PROCESSING_REC.INTERNAL_CREATION_DATE   ,TO_DATE('01/01/0001 00:00:00','DD/MM/YYYY HH24:MI:SS'))
          --AND   NVL(SERVICE_CODE_SENDING_FILE,'X')                          = NVL(P_PCRD_FILE_PROCESSING_REC.SERVICE_CODE_SENDING_FILE,'X')
          AND   NVL(FIRST_RECORD_FILE        ,'X')                          = NVL(P_PCRD_FILE_PROCESSING_REC.FIRST_RECORD_FILE        ,'X')
          AND   RECORD_FLAG                                                 = GLOBAL_VARS_4.BATCH_REC
          AND   GLOBAL_REJECT_FILE                                          = GLOBAL_VARS.NO;
        EXCEPTION
        WHEN OTHERS THEN


            V_ENV_INFO_TRACE.ERROR_CODE   := 'PWC-00021';
            V_ENV_INFO_TRACE.PARAM1       := 'PCRD_FILE_PROCESSING';
            V_ENV_INFO_TRACE.PARAM2       := 'PHYSICAL_FILE_NAME = ' || P_PCRD_FILE_PROCESSING_REC.PHYSICAL_FILE_NAME ||
                                             ', NVL(INTERNAL_FILE_NAME  ,''X'') = '  || NVL(P_PCRD_FILE_PROCESSING_REC.INTERNAL_FILE_NAME       ,'X') ||
                                              ', NVL(INTERNAL_SEQUENCE_FILE ,''X'') = ' || NVL(P_PCRD_FILE_PROCESSING_REC.INTERNAL_SEQUENCE_FILE   ,'X') ||
                                              ', NVL(INTERNAL_CREATION_DATE ,TO_DATE(''01/01/0001 00:00:00'',''DD/MM/YYYY HH24:MI:SS''))   = ' || NVL(P_PCRD_FILE_PROCESSING_REC.INTERNAL_CREATION_DATE   ,TO_DATE('01/01/0001 00:00:00','DD/MM/YYYY HH24:MI:SS')) ||
                                              ', NVL(SERVICE_CODE_SENDING_FILE,''X'') = ' || NVL(P_PCRD_FILE_PROCESSING_REC.SERVICE_CODE_SENDING_FILE,'X') ||
                                              ', NVL(FIRST_RECORD_FILE ,''X'') = ' || NVL(P_PCRD_FILE_PROCESSING_REC.FIRST_RECORD_FILE        ,'X') ||
                                              ', RECORD_FLAG = ' || GLOBAL_VARS_4.BATCH_REC ||
                                              ', GLOBAL_REJECT_FILE = ' || GLOBAL_VARS.NO;

            V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR IN SELECT  PCRD_FILE_PROCESSING ';
            PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
            RETURN  (DECLARATION_CST.ERROR);
    END;

    IF    V_NBR_RECORD <> 0
    THEN
        V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR: FILE ALREADY PROCESSED:'||P_PCRD_FILE_PROCESSING_REC.INTERNAL_SEQUENCE_FILE;
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN  (DECLARATION_CST.NOK);
    END IF;
 RETURN(DECLARATION_CST.OK);



EXCEPTION
WHEN OTHERS THEN
    V_ENV_INFO_TRACE.USER_MESSAGE := NULL;
    PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
    RETURN  (DECLARATION_CST.ERROR);
END CHECKS_FILE_PROCESSING;

FUNCTION    PROC_ACK_FILE_PROC_DETAIL          (   P_BUSINESS_DATE           IN   DATE,
                                                   P_TASK_NAME               IN   PCARD_TASKS.TASK_NAME%TYPE,
                                                   P_INTERNAL_FILE_NAME      IN   PCRD_FILE_PROCESSING.INTERNAL_FILE_NAME%TYPE,
                                                   P_PHYSICAL_FILE_NAME      IN   PCRD_FILE_PROCESSING.PHYSICAL_FILE_NAME%TYPE,
                                                   P_SEQ_NUM                 IN   ACK_FILE_BUFFER.SEQUENCE_NUMBER%TYPE,
                                                   P_IS_FILE_ALREADY_PROCESSED IN PLS_INTEGER          )
                                               RETURN PLS_INTEGER  IS

V_ENV_INFO_TRACE                GLOBAL_VARS.ENV_INFO_TRACE_TYPE;
RETURN_STATUS                   PLS_INTEGER;
V_PROCESSING_RESULT             ACK_FILE_DETAIL.PROCESSING_RESULT%TYPE;
V_CONTROL_STATUS_BUFFER         ACK_FILE_DETAIL.CONTROL_STATUS_BUFFER%TYPE;



ERR_INIT_COUNTERS               CONSTANT PLS_INTEGER := 8033.; -- ERROR INITIALIZING BATCH COUNTERS
ERR_CALCULATE_COUNTERS          CONSTANT PLS_INTEGER := 8034.; -- ERROR CALCULATE BATCH COUNTERS
P_COUNTER_1                     PCARD_TASKS.COUNTER_1%TYPE:=0;
P_COUNTER_2                     PCARD_TASKS.COUNTER_2%TYPE:=0;
P_COUNTER_3                     PCARD_TASKS.COUNTER_3%TYPE:=0;
P_COUNTER_4                     PCARD_TASKS.COUNTER_3%TYPE:=0;
P_AMOUNT_1                      PCARD_TASKS.AMOUNT_1%TYPE:=0;
P_AMOUNT_2                      PCARD_TASKS.AMOUNT_2%TYPE:=0;
P_AMOUNT_3                      PCARD_TASKS.AMOUNT_3%TYPE:=0;
P_AMOUNT_4                      PCARD_TASKS.AMOUNT_3%TYPE:=0;


CURSOR CUR_ACK_FILE_DETAIL
    IS  SELECT   *
        FROM     ACK_FILE_DETAIL
        WHERE SEQUENCE_NUMBER=P_SEQ_NUM
        FOR      UPDATE;
BEGIN
    --------------------------------------------------------------------
    V_ENV_INFO_TRACE.BUSINESS_DATE  :=  P_BUSINESS_DATE;
    V_ENV_INFO_TRACE.USER_NAME      :=  GLOBAL_VARS.USER_NAME;
    V_ENV_INFO_TRACE.MODULE_CODE    :=  GLOBAL_VARS.ML_CREDIT_REVOLVING;
    V_ENV_INFO_TRACE.PACKAGE_NAME   :=  $$PLSQL_UNIT;
    V_ENV_INFO_TRACE.FUNCTION_NAME  :=  'PROC_ACK_FILE_PROC_DETAIL';
    V_ENV_INFO_TRACE.LANG           :=  GLOBAL_VARS.LANG;
    --------------------------------------------------------------------

    PCRD_ERRORS.TASK_NAME := P_TASK_NAME;

    -- START INIT COUNTERS MANAGEMENT
    RETURN_STATUS   :=  PCRD_CAI_GENERAL_TOOLS_1.INIT_COUNTERS;
    IF  RETURN_STATUS   <>  DECLARATION_CST.OK
    THEN
        V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR REURNED BY PCRD_CAI_GENERAL_TOOLS_1.INIT_COUNTERS ';
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN( ERR_INIT_COUNTERS );
    END IF;
    -- END INIT COUNTERS MANAGEMENT


    FOR ENR_ACK_FILE_DETAIL IN CUR_ACK_FILE_DETAIL
    LOOP
        V_CONTROL_STATUS_BUFFER     :=  RPAD('0', 8 , '0');-- 8 IS THE INDEX OF THE LAST XML TAG - SEE PACKAGE ACK_FILE_GLOBAL_VARS
        V_PROCESSING_RESULT         :=  ACK_FILE_GLOBAL_VARS.PROCESSED;
        P_COUNTER_1   := P_COUNTER_1 + 1;

        IF P_IS_FILE_ALREADY_PROCESSED <> 1
        THEN
             IF TRIM(ENR_ACK_FILE_DETAIL.RECORD_NO) IS NULL
             THEN
                 V_PROCESSING_RESULT   :=  ACK_FILE_GLOBAL_VARS.REJECTED;
                PCRD_GENERAL_TOOLS.IN_STR (V_CONTROL_STATUS_BUFFER, ACK_FILE_GLOBAL_VARS.RECORD_NO, ACK_FILE_GLOBAL_VARS.NULL_VALUE);

             ELSIF NOT PCRD_CB_TOOLS.IS_NUMERIC (TRIM(ENR_ACK_FILE_DETAIL.RECORD_NO))
             THEN
                 V_PROCESSING_RESULT   :=  ACK_FILE_GLOBAL_VARS.REJECTED;
                PCRD_GENERAL_TOOLS.IN_STR (V_CONTROL_STATUS_BUFFER, ACK_FILE_GLOBAL_VARS.RECORD_NO, ACK_FILE_GLOBAL_VARS.NOT_NUMERIC);

             END IF;

          IF ACK_FILE_GLOBAL_VARS.ENABLE_CTRL = 'Y'
          THEN

             IF ENR_ACK_FILE_DETAIL.ENTITY_CODE IS NULL
             THEN
                 V_PROCESSING_RESULT   :=  ACK_FILE_GLOBAL_VARS.REJECTED;
                PCRD_GENERAL_TOOLS.IN_STR (V_CONTROL_STATUS_BUFFER, ACK_FILE_GLOBAL_VARS.ENTITY_CODE, ACK_FILE_GLOBAL_VARS.NULL_VALUE);
             END IF;

             IF  ENR_ACK_FILE_DETAIL.ENTITY_TYPE IS NULL
             THEN
                 V_PROCESSING_RESULT  :=  ACK_FILE_GLOBAL_VARS.REJECTED;
                PCRD_GENERAL_TOOLS.IN_STR (V_CONTROL_STATUS_BUFFER, ACK_FILE_GLOBAL_VARS.ENTITY_TYPE, ACK_FILE_GLOBAL_VARS.NULL_VALUE);
             END IF;

             IF  ENR_ACK_FILE_DETAIL.PASSPORT_NO IS NULL
             THEN
                 V_PROCESSING_RESULT  :=  ACK_FILE_GLOBAL_VARS.REJECTED;
                PCRD_GENERAL_TOOLS.IN_STR (V_CONTROL_STATUS_BUFFER, ACK_FILE_GLOBAL_VARS.PASSPORT_NO, ACK_FILE_GLOBAL_VARS.NULL_VALUE);
             END IF;

             IF  ENR_ACK_FILE_DETAIL.COUNTRY_CODE IS NULL
             THEN
                 V_PROCESSING_RESULT  :=  ACK_FILE_GLOBAL_VARS.REJECTED;
                PCRD_GENERAL_TOOLS.IN_STR (V_CONTROL_STATUS_BUFFER, ACK_FILE_GLOBAL_VARS.COUNTRY_CODE, ACK_FILE_GLOBAL_VARS.NULL_VALUE);
             END IF;

             IF TRIM(ENR_ACK_FILE_DETAIL.REF_NO) IS NULL
             THEN
                 V_PROCESSING_RESULT   :=  ACK_FILE_GLOBAL_VARS.REJECTED;
                PCRD_GENERAL_TOOLS.IN_STR (V_CONTROL_STATUS_BUFFER, ACK_FILE_GLOBAL_VARS.REF_NO, ACK_FILE_GLOBAL_VARS.NULL_VALUE);

             ELSIF NOT PCRD_CB_TOOLS.IS_NUMERIC (TRIM(ENR_ACK_FILE_DETAIL.REF_NO))
             THEN
                 V_PROCESSING_RESULT   :=  ACK_FILE_GLOBAL_VARS.REJECTED;
                PCRD_GENERAL_TOOLS.IN_STR (V_CONTROL_STATUS_BUFFER, ACK_FILE_GLOBAL_VARS.REF_NO, ACK_FILE_GLOBAL_VARS.NOT_NUMERIC);

             END IF;

             IF TRIM(ENR_ACK_FILE_DETAIL.UNIQUE_REF_ID) IS NULL
             THEN
                 V_PROCESSING_RESULT   :=  ACK_FILE_GLOBAL_VARS.REJECTED;
                PCRD_GENERAL_TOOLS.IN_STR (V_CONTROL_STATUS_BUFFER, ACK_FILE_GLOBAL_VARS.UNIQUE_REF_ID, ACK_FILE_GLOBAL_VARS.NULL_VALUE);

             ELSIF NOT PCRD_CB_TOOLS.IS_NUMERIC (TRIM(ENR_ACK_FILE_DETAIL.UNIQUE_REF_ID))
             THEN
                 V_PROCESSING_RESULT   :=  ACK_FILE_GLOBAL_VARS.REJECTED;
                 PCRD_GENERAL_TOOLS.IN_STR (V_CONTROL_STATUS_BUFFER, ACK_FILE_GLOBAL_VARS.UNIQUE_REF_ID, ACK_FILE_GLOBAL_VARS.NOT_NUMERIC);
             END IF;

             IF  ENR_ACK_FILE_DETAIL.DETAILS_MSG_DESC IS NULL
             THEN
                 V_PROCESSING_RESULT  :=  ACK_FILE_GLOBAL_VARS.REJECTED;
                PCRD_GENERAL_TOOLS.IN_STR (V_CONTROL_STATUS_BUFFER, ACK_FILE_GLOBAL_VARS.DETAILS_MSG_DESC, ACK_FILE_GLOBAL_VARS.NULL_VALUE);
             END IF;
          END IF;
        ELSE
            V_PROCESSING_RESULT  :=  ACK_FILE_GLOBAL_VARS.REJECTED;
            V_CONTROL_STATUS_BUFFER :='99999999'; --FILE_ALREADY_PROCESSED

        END IF;



             IF V_PROCESSING_RESULT = ACK_FILE_GLOBAL_VARS.PROCESSED
             THEN
                 P_COUNTER_2   := P_COUNTER_2 + 1;

             ELSIF V_PROCESSING_RESULT = ACK_FILE_GLOBAL_VARS.REJECTED
             THEN
                 P_COUNTER_3   := P_COUNTER_3 + 1;

             END IF;

        BEGIN
            UPDATE ACK_FILE_DETAIL
            SET    PROCESSING_RESULT        = V_PROCESSING_RESULT,
                   CONTROL_STATUS_BUFFER    = V_CONTROL_STATUS_BUFFER,
                   --INTERNAL_FILE_NAME       =  P_INTERNAL_FILE_NAME,
                   PHYSICAL_FILE_NAME       =  P_PHYSICAL_FILE_NAME
            WHERE  CURRENT OF CUR_ACK_FILE_DETAIL;

            IF SQL%ROWCOUNT <> 1
            THEN

                V_ENV_INFO_TRACE.ERROR_CODE     :=  GLOBAL_VARS_ERRORS.DUP_VAL_ON_UPDATE;
                V_ENV_INFO_TRACE.PARAM1         :=  'ACK_FILE_DETAIL';
                V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR ON UPDATE ACK_FILE_DETAIL';
                PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
            END IF;
        END;


    END LOOP;

    -- START COUNTERS MANAGEMENT
    RETURN_STATUS   :=  PCRD_CAI_ERRORS.UPD_TASK_COUNTER(   P_COUNTER_1,
                                                            P_COUNTER_2,
                                                            P_COUNTER_3,
                                                            P_COUNTER_4,
                                                            0,
                                                            P_AMOUNT_1,
                                                            P_AMOUNT_2,
                                                            P_AMOUNT_3,
                                                            P_AMOUNT_4,
                                                            0,
                                                            FALSE );
    IF  RETURN_STATUS   <>  DECLARATION_CST.OK
    THEN
        V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR RETURNED BY PCRD_CAI_ERRORS.UPD_TASK_COUNTER ';
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN( ERR_CALCULATE_COUNTERS );
    END IF;
    -- END COUNTERS MANAGEMENT
/* MH 23012023 - PROCESS ENTRIES IN ACK_FILE_DETAIL - START */
     V_ENV_INFO_TRACE.USER_MESSAGE :=  'BEFORE ENTERING PCRD_ACKNOWLEDGEMENT_FILE.PROCESS_ACK_FILE_DETAIL_TABLE' || P_SEQ_NUM ;
     PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);

     V_ENV_INFO_TRACE.USER_MESSAGE :=  'BEFORE ENTERING PCRD_ACKNOWLEDGEMENT_FILE.P_INTERNAL_FILE_NAME' || P_INTERNAL_FILE_NAME ;
     PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);


     RETURN_STATUS   := PCRD_ACKNOWLEDGEMENT_FILE.PROCESS_ACK_FILE_DETAIL_TABLE(P_SEQ_NUM);

     V_ENV_INFO_TRACE.USER_MESSAGE :=  'P_SEQ_NUM' || P_SEQ_NUM;
     PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);

     V_ENV_INFO_TRACE.USER_MESSAGE :=  'RETURN_STATUS' || RETURN_STATUS;
     PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);

      /* MH 23012023 - PROCESS ENTRIES IN ACK_FILE_DETAIL - END */
    RETURN  DECLARATION_CST.OK;

EXCEPTION WHEN OTHERS
THEN
    V_ENV_INFO_TRACE.ERROR_CODE     :=  GLOBAL_VARS_ERRORS.ORACLE_ERROR;
    V_ENV_INFO_TRACE.USER_MESSAGE   :=  ' OTHERS ERROR:  ' || SUBSTR (SQLERRM, 1, 100);
    PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
    RETURN  DECLARATION_CST.ERROR;
END PROC_ACK_FILE_PROC_DETAIL;
--------------------------------------------------------------------------------------
/* START - MH 23012023 -- ADDED FUNCTION PROCESS_ACK_FILE_DETAIL_TABLE - START */
FUNCTION    PROCESS_ACK_FILE_DETAIL_TABLE      (  P_SEQ_NUM                 IN   ACK_FILE_DETAIL.SEQUENCE_NUMBER%TYPE)

                                               RETURN PLS_INTEGER  IS

V_ENV_INFO_TRACE                GLOBAL_VARS.ENV_INFO_TRACE_TYPE;
RETURN_STATUS                   PLS_INTEGER;
V_PROCESSING_RESULT             ACK_FILE_DETAIL.PROCESSING_RESULT%TYPE;
V_STATUS_MSG                    VARCHAR2(100);
V_CONTROL_STATUS_BUFFER         ACK_FILE_DETAIL.CONTROL_STATUS_BUFFER%TYPE;
V_ACK_MAPPING_EC                ACK_MAPPING_TABLE%ROWTYPE;
V_ACK_MAPPING_UR                ACK_MAPPING_TABLE%ROWTYPE;

V_CLIENT_RECORD                 CLIENT%ROWTYPE;
V_SHADOW_ACCOUNT_NBR            SHADOW_ACCOUNT%ROWTYPE;
V_PWC_INTR_REF                  CARD%ROWTYPE;
V_INTERNAL_FILE_NAME3           ACK_FILE_DETAIL.INTERNAL_FILE_NAME%TYPE;
V_INTERNAL_FILE_NAME            ACK_FILE_HEADER.FILE_NAME%TYPE;
V_ENTITY_CODE                   ACK_FILE_DETAIL.ENTITY_CODE%TYPE;

ERR_INIT_COUNTERS               CONSTANT PLS_INTEGER := 8033.; -- ERROR INITIALIZING BATCH COUNTERS
ERR_CALCULATE_COUNTERS          CONSTANT PLS_INTEGER := 8034.; -- ERROR CALCULATE BATCH COUNTERS
P_COUNTER_1                     PCARD_TASKS.COUNTER_1%TYPE:=0;
P_COUNTER_2                     PCARD_TASKS.COUNTER_2%TYPE:=0;
P_COUNTER_3                     PCARD_TASKS.COUNTER_3%TYPE:=0;
P_COUNTER_4                     PCARD_TASKS.COUNTER_4%TYPE:=0;
P_AMOUNT_1                      PCARD_TASKS.AMOUNT_1%TYPE:=0;
P_AMOUNT_2                      PCARD_TASKS.AMOUNT_2%TYPE:=0;
P_AMOUNT_3                      PCARD_TASKS.AMOUNT_3%TYPE:=0;
P_AMOUNT_4                      PCARD_TASKS.AMOUNT_4%TYPE:=0;
--V_STATUS_MSG                    VARCHAR2(100); --:= ACK_FILE_GLOBAL_VARS.EXIST_DIF_REF_ID_ENTITY_MATCH;

CURSOR CUR_INT_FILE_NAME
        IS
        SELECT FILE_NAME
        FROM ACK_FILE_HEADER
        ORDER BY FILE_NAME ASC;


CURSOR CUR_PROC_ACK_FILE_DETAIL (P_FILE_NAME VARCHAR2)
        IS
        SELECT   *
        FROM     ACK_FILE_DETAIL
        WHERE SEQUENCE_NUMBER=P_SEQ_NUM
        --RECORD_NO = P_REC_NO
        AND
        PROCESSING_RESULT = 'P' -- ADDED BY MH23012023
        AND CONTROL_STATUS_BUFFER = '00000000'-- ADDED BY MH23012023
        AND INTERNAL_FILE_NAME = P_FILE_NAME

        ORDER BY INTERNAL_FILE_NAME ASC;
        --FOR      UPDATE;

BEGIN
    --------------------------------------------------------------------
    --V_ENV_INFO_TRACE.BUSINESS_DATE  :=  P_BUSINESS_DATE;
    V_ENV_INFO_TRACE.USER_NAME      :=  GLOBAL_VARS.USER_NAME;
    V_ENV_INFO_TRACE.MODULE_CODE    :=  GLOBAL_VARS.ML_CREDIT_REVOLVING;
    V_ENV_INFO_TRACE.PACKAGE_NAME   :=  $$PLSQL_UNIT;
    V_ENV_INFO_TRACE.FUNCTION_NAME  :=  'PROCESS_ACK_FILE_DETAIL_TABLE';
    V_ENV_INFO_TRACE.LANG           :=  GLOBAL_VARS.LANG;
    --------------------------------------------------------------------.

    V_ENV_INFO_TRACE.USER_MESSAGE :=  'P_SEQ_NUM IN PROCESS_ACK_FILE_DETAIL_TABLE: ' || P_SEQ_NUM;
    PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);

   /* FOR PROC_INT_FILE_NAME IN CUR_INT_FILE_NAME
    LOOP

    V_ENV_INFO_TRACE.USER_MESSAGE :=  'V_INTERNAL_FILE_NAME: ' || V_INTERNAL_FILE_NAME;
    PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
    */
    
    --START Ajhar20231113
    /* ARCHIVE SUCCESS & REJECT TABLES */
    RETURN_STATUS   :=  PCRD_ACKNOWLEDGEMENT_FILE.ARCHIVE_SUCCESS_REJECT_TABLES;
    IF  RETURN_STATUS   <>  DECLARATION_CST.OK
    THEN
        V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR REURNED BY PCRD_ACKNOWLEDGEMENT_FILE.ARCHIVE_SUCCESS_REJECT_TABLES ';
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN( RETURN_STATUS );
    END IF;
    /* ARCHIVE SUCCESS & REJECT TABLES*/
    --END Ajhar20231113


    FOR PROC_ACK_FILE_NAME IN CUR_INT_FILE_NAME
    LOOP


                FOR PROC_ACK_FILE_DETAIL IN CUR_PROC_ACK_FILE_DETAIL (PROC_ACK_FILE_NAME.FILE_NAME)
                LOOP

                BEGIN

                    IF PROC_ACK_FILE_DETAIL.ENTITY_TYPE IN ('C','P')
                    THEN
                            V_ENTITY_CODE := PROC_ACK_FILE_DETAIL.ENTITY_TYPE||PROC_ACK_FILE_DETAIL.ENTITY_CODE;

                    ELSE
                            V_ENTITY_CODE := PROC_ACK_FILE_DETAIL.ENTITY_CODE;
                    END IF;
                    
                    --START AJHAR 20230907
                    SELECT * INTO V_CLIENT_RECORD
                    FROM CLIENT C
                    WHERE C.LEGAL_ID=V_ENTITY_CODE
                    AND C.OWNER_CATEGORY = PROC_ACK_FILE_DETAIL.ENTITY_TYPE --YM04072023 - ADDED OWNER CODE CRITERIA
                    AND ROWNUM=1;--ADDED ON 16 MARCH
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        V_ENV_INFO_TRACE.USER_MESSAGE :=  'FIRST QUERY NO DATA FOUND FOR ENTITY_CODE -> LEGAL ID: ' || PROC_ACK_FILE_DETAIL.ENTITY_CODE;
                        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                END;
                    --END AJHAR 20230907
                                    
                BEGIN
                    --START AJHAR 20230907
                    SELECT * INTO V_PWC_INTR_REF
                    FROM CARD CA
                    WHERE PROC_ACK_FILE_DETAIL.REF_NO=CA.PWRCD_INTERNAL_REFERENCE  
                    AND ROWNUM=1;  --AJHAR
                    /*
                    SELECT * INTO V_CLIENT_RECORD
                    FROM CLIENT C
                    WHERE C.LEGAL_ID=V_ENTITY_CODE
                    AND C.OWNER_CATEGORY = PROC_ACK_FILE_DETAIL.ENTITY_TYPE --YM04072023 - ADDED OWNER CODE CRITERIA
                    AND ROWNUM=1;--ADDED ON 16 MARCH
                    */
                    --END AJHAR 20230907

                    EXCEPTION
                            WHEN NO_DATA_FOUND  
                    THEN

                        V_ENV_INFO_TRACE.USER_MESSAGE :=  'IN CARD TABLE NO CLIENT RECORD FOUND FOR REF_NO: ' || PROC_ACK_FILE_DETAIL.REF_NO;   --AJHAR 20230907
                        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);

                        BEGIN
                            --START AJHAR 20230907
                            SELECT * INTO V_SHADOW_ACCOUNT_NBR
                            FROM shadow_account SH
                            WHERE PROC_ACK_FILE_DETAIL.REF_NO=SH.Shadow_Account_nbr  
                            AND ROWNUM=1;
                            --END AJHAR 20230907

                            EXCEPTION
                                    WHEN NO_DATA_FOUND
                            THEN
                                    V_STATUS_MSG := ACK_FILE_GLOBAL_VARS.CLIENT_NOT_EXIST;
                                    RETURN_STATUS   :=  PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_REJECT (PROC_ACK_FILE_DETAIL.RECORD_NO,PROC_ACK_FILE_NAME.FILE_NAME,P_SEQ_NUM, V_STATUS_MSG);
                                    IF RETURN_STATUS <> DECLARATION_CST.OK
                                            THEN
                                                V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR RETURNED BY PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_REJECT ';
                                                PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                                     RETURN (RETURN_STATUS);
                                    END IF;

                                    CONTINUE;
                        END;


                END;

                    /*YM04072023 - ADD LOGIC TO TREAT UNIQUE_REF_ID WITH VALUE 'NOT FOUND'*/

                    BEGIN
                           IF PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID IS NULL
                            THEN

                                V_ENV_INFO_TRACE.USER_MESSAGE :=  'UNIQUE REF ID IS NOT FOUND FOR REF NO ' ||PROC_ACK_FILE_DETAIL.REF_NO;
                                PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);

                                V_STATUS_MSG := ACK_FILE_GLOBAL_VARS.UNIQUE_REF_ID_NULL;

                                RETURN_STATUS   :=  PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_REJECT (PROC_ACK_FILE_DETAIL.RECORD_NO,PROC_ACK_FILE_NAME.FILE_NAME,P_SEQ_NUM, V_STATUS_MSG);

                                IF RETURN_STATUS <> DECLARATION_CST.OK
                                    THEN
                                        V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR REURNED BY PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_REJECT ';
                                        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                                    RETURN (RETURN_STATUS);
                                END IF;

                                CONTINUE;

                            END IF;
                     END;

                        BEGIN
                            SELECT  *
                            INTO    V_ACK_MAPPING_EC
                            FROM    ACK_MAPPING_TABLE A
                            WHERE   A.REF_NO=PROC_ACK_FILE_DETAIL.REF_NO
                            AND ROWNUM = 1; --AJHAR 20230906
                            --START AJHAR 20230907
                            BEGIN
                                    SELECT  *
                                    INTO    V_ACK_MAPPING_UR
                                    FROM    ACK_MAPPING_TABLE A
                                    WHERE   A.UNIQUE_REF_ID=PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID
                                    AND ROWNUM = 1; --AJHAR 20230906
                            EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                V_ENV_INFO_TRACE.USER_MESSAGE :=  'UP -> NO DATA FOUND IN ACK_MAPPING_TABLE FOR UNIQUE REF ID: ' || PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID;
                                PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                            END;
                            --START AJHAR 20230907

                            --V_ENV_INFO_TRACE.USER_MESSAGE :=  'ENTERED 8TH CONDITION: ' || PROC_ACK_FILE_DETAIL.RECORD_NO || 'PROC_ACK_FILE_DETAIL.REF_NO :' || PROC_ACK_FILE_DETAIL.REF_NO || ' PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID :' || PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID || ' V_ENTITY_CODE: ' || V_ENTITY_CODE || ' V_CLIENT_RECORD.LEGAL_ID : ' || V_CLIENT_RECORD.LEGAL_ID;
                            --PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);

                               

                            -- 5. REF_NO,UNIQUE_REF_ID IN ACK_MAPPING_TABLE AND ENTITY_CODE EQUAL LEGAL_ID IN CLIENT TABLE
                            IF  V_ACK_MAPPING_EC.REF_NO                    IS NOT NULL
                            AND NVL(PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID, 'X')      = NVL(V_ACK_MAPPING_UR.UNIQUE_REF_ID, 'X') --AJHAR 20230907
                            AND NVL(V_ENTITY_CODE,'X')               = NVL(V_CLIENT_RECORD.LEGAL_ID, 'X')
                            THEN

                                V_ENV_INFO_TRACE.USER_MESSAGE :=  'ENTERED 5TH CONDITION: ' || PROC_ACK_FILE_DETAIL.RECORD_NO || 'PROC_ACK_FILE_DETAIL.REF_NO :' || PROC_ACK_FILE_DETAIL.REF_NO || ' PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID :' || PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID || ' V_ENTITY_CODE: ' || V_ENTITY_CODE || ' V_CLIENT_RECORD.LEGAL_ID : ' || V_CLIENT_RECORD.LEGAL_ID;
                                PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);


                                V_STATUS_MSG := ACK_FILE_GLOBAL_VARS.EXIST_REF_ID_ENT_MATCH;
                                RETURN_STATUS   :=  PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_SUCCESS (PROC_ACK_FILE_DETAIL.RECORD_NO,PROC_ACK_FILE_NAME.FILE_NAME,P_SEQ_NUM,V_STATUS_MSG);

                                IF RETURN_STATUS <> DECLARATION_CST.OK
                                    THEN
                                        V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR REURNED BY PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_SUCCESS ';
                                        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                                    RETURN (RETURN_STATUS);

                                END IF;
                            -- 8. REF_NO,UNIQUE_REF_ID IN ACK_MAPPING_TABLE AND ENTITY_CODE NOT EQUAL LEGAL_ID IN CLIENT TABLE
                            /*ELSIF   V_ACK_MAPPING_EC.REF_NO        IS NOT NULL
                            AND     V_ACK_MAPPING_EC.UNIQUE_REF_ID IS NULL
                            AND     V_ENTITY_CODE               <> V_CLIENT_RECORD.LEGAL_ID
                            THEN

                              V_ENV_INFO_TRACE.USER_MESSAGE :=  'ENTERED 8TH CONDITION: ' || PROC_ACK_FILE_DETAIL.RECORD_NO || 'PROC_ACK_FILE_DETAIL.REF_NO :' || PROC_ACK_FILE_DETAIL.REF_NO || ' PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID :' || PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID || ' V_ENTITY_CODE: ' || V_ENTITY_CODE || ' V_CLIENT_RECORD.LEGAL_ID : ' || V_CLIENT_RECORD.LEGAL_ID;
                                PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);

                                V_STATUS_MSG := ACK_FILE_GLOBAL_VARS.EXIST_DIF_REF_ID_ENT_NOT_MATCH;

                                RETURN_STATUS   :=  PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_REJECT (PROC_ACK_FILE_DETAIL.RECORD_NO,PROC_ACK_FILE_NAME.FILE_NAME,P_SEQ_NUM, V_STATUS_MSG);


                                IF RETURN_STATUS <> DECLARATION_CST.OK
                                    THEN
                                        V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR REURNED BY PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_REJECT ';
                                        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                                    RETURN (RETURN_STATUS);

                                END IF;
                                */
                            
                            ELSIF   V_ACK_MAPPING_EC.REF_NO        IS NOT NULL
                            AND     NVL(PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID, 'X')      != NVL(V_ACK_MAPPING_UR.UNIQUE_REF_ID, 'X')  --AJHAR 20230907
                            --AND     TRIM(PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID) = 'NOT FOUND'
                            AND     NVL(V_ENTITY_CODE,'X')               != NVL(V_CLIENT_RECORD.LEGAL_ID, 'X') --SAMPLE 2
                            /*--START AJHAR 20230901
                            OR
                            (PROC_ACK_FILE_DETAIL.REF_NO = V_ACK_MAPPING_EC.REF_NO
                            AND     NVL(PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID, 'X')      = NVL(V_ACK_MAPPING_UR.UNIQUE_REF_ID, 'X')  --AJHAR 20230907
                            AND     NVL(PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID, 'X') != NVL(V_ACK_MAPPING_EC.UNIQUE_REF_ID, 'X')
                            AND     NVL(V_ENTITY_CODE,'X')               = NVL(V_CLIENT_RECORD.LEGAL_ID, 'X')) --SAMPLE 4 & 5c
                            --END AJHAR 20230901*/
                            
                            THEN

                              V_ENV_INFO_TRACE.USER_MESSAGE :=  'ENTERED 8TH CONDITION: ' || PROC_ACK_FILE_DETAIL.RECORD_NO || 'PROC_ACK_FILE_DETAIL.REF_NO :' || PROC_ACK_FILE_DETAIL.REF_NO || ' PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID :' || PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID || ' V_ENTITY_CODE: ' || V_ENTITY_CODE || ' V_CLIENT_RECORD.LEGAL_ID : ' || V_CLIENT_RECORD.LEGAL_ID;
                                PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);

                                V_STATUS_MSG := ACK_FILE_GLOBAL_VARS.EXIST_DIF_REF_ID_ENT_NOT_MATCH;

                                RETURN_STATUS   :=  PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_REJECT (PROC_ACK_FILE_DETAIL.RECORD_NO,PROC_ACK_FILE_NAME.FILE_NAME,P_SEQ_NUM, V_STATUS_MSG);


                                IF RETURN_STATUS <> DECLARATION_CST.OK
                                    THEN
                                        V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR REURNED BY PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_REJECT ';
                                        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                                    RETURN (RETURN_STATUS);

                                END IF;

                                --START AJHAR 20230901
                                RETURN_STATUS   :=  PCRD_ACKNOWLEDGEMENT_FILE.UPDATE_ACK_MAPPING_TABLE (PROC_ACK_FILE_DETAIL.REF_NO,PROC_ACK_FILE_DETAIL.RECORD_NO,V_ENTITY_CODE,PROC_ACK_FILE_NAME.FILE_NAME,P_SEQ_NUM);

                                IF RETURN_STATUS <> DECLARATION_CST.OK
                                    THEN
                                        V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR REURNED BY PCRD_ACKNOWLEDGEMENT_FILE.UPDATE_ACK_MAPPING_TABLE ';
                                        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                                    RETURN (RETURN_STATUS);
                                END IF;
                            
                                --END AJHAR 20230901
                            -- 6. REF_NO IN ACK_MAPPING_TABLE, UNIQUE_REF_ID NOT IN ACK_MAPPING_TABLE AND ENTITY_CODE EQUAL LEGAL_ID IN CLIENT TABLE
                            ELSIF  V_ACK_MAPPING_EC.REF_NO         IS NOT NULL
                            AND    NVL(PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID, 'X')      != NVL(V_ACK_MAPPING_UR.UNIQUE_REF_ID, 'X')  --AJHAR 20230907
                            AND    NVL(V_ENTITY_CODE,'X')               = NVL(V_CLIENT_RECORD.LEGAL_ID, 'X')
                            THEN

                                V_ENV_INFO_TRACE.USER_MESSAGE :=  'ENTERED 6TH CONDITION: ' || PROC_ACK_FILE_DETAIL.RECORD_NO || 'PROC_ACK_FILE_DETAIL.REF_NO :' || PROC_ACK_FILE_DETAIL.REF_NO || ' PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID :' || PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID || ' V_ENTITY_CODE: ' || V_ENTITY_CODE || ' V_CLIENT_RECORD.LEGAL_ID : ' || V_CLIENT_RECORD.LEGAL_ID;
                                PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);


                                V_STATUS_MSG := ACK_FILE_GLOBAL_VARS.EXIST_DIF_REF_ID_ENT_MATCH;
                                RETURN_STATUS   :=  PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_REJECT (PROC_ACK_FILE_DETAIL.RECORD_NO,PROC_ACK_FILE_NAME.FILE_NAME,P_SEQ_NUM, V_STATUS_MSG);

                                IF RETURN_STATUS <> DECLARATION_CST.OK
                                    THEN
                                        V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR REURNED BY PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_REJECT ';
                                        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                                    RETURN (RETURN_STATUS);
                                END IF;


                            -- 7. REF_NO,UNIQUE_REF_ID IN ACK_MAPPING_TABLE AND ENTITY_CODE NOT EQUAL LEGAL_ID IN CLIENT TABLE
                            ELSIF   V_ACK_MAPPING_EC.REF_NO        IS NOT NULL
                            AND     NVL(PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID, 'X')      = NVL(V_ACK_MAPPING_UR.UNIQUE_REF_ID, 'X')  --AJHAR 20230907
                            AND     NVL(V_ENTITY_CODE,'X')               != NVL(V_CLIENT_RECORD.LEGAL_ID, 'X')
                            THEN

                                V_ENV_INFO_TRACE.USER_MESSAGE :=  'ENTERED 7TH CONDITION: ' || PROC_ACK_FILE_DETAIL.RECORD_NO || 'PROC_ACK_FILE_DETAIL.REF_NO :' || PROC_ACK_FILE_DETAIL.REF_NO || ' PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID :' || PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID || ' V_ENTITY_CODE: ' || V_ENTITY_CODE || ' V_CLIENT_RECORD.LEGAL_ID : ' || V_CLIENT_RECORD.LEGAL_ID;
                                PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);


                                V_STATUS_MSG := ACK_FILE_GLOBAL_VARS.EXIST_SAME_REF_ID_ENT_MATCH;
                                RETURN_STATUS   :=  PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_SUCCESS (PROC_ACK_FILE_DETAIL.RECORD_NO,PROC_ACK_FILE_NAME.FILE_NAME,P_SEQ_NUM, V_STATUS_MSG);

                                IF RETURN_STATUS <> DECLARATION_CST.OK
                                    THEN
                                        V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR REURNED BY PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_SUCCESS ';
                                        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                                    RETURN (RETURN_STATUS);
                                END IF;

                                RETURN_STATUS   :=  PCRD_ACKNOWLEDGEMENT_FILE.UPDATE_ACK_MAPPING_TABLE (PROC_ACK_FILE_DETAIL.REF_NO,PROC_ACK_FILE_DETAIL.RECORD_NO,V_ENTITY_CODE,PROC_ACK_FILE_NAME.FILE_NAME,P_SEQ_NUM);

                                IF RETURN_STATUS <> DECLARATION_CST.OK
                                    THEN
                                        V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR REURNED BY PCRD_ACKNOWLEDGEMENT_FILE.UPDATE_ACK_MAPPING_TABLE ';
                                        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                                    RETURN (RETURN_STATUS);
                                END IF;

                           /*-- 8. REF_NO,UNIQUE_REF_ID IN ACK_MAPPING_TABLE AND ENTITY_CODE NOT EQUAL LEGAL_ID IN CLIENT TABLE
                            ELSIF   V_ACK_MAPPING_EC.REF_NO        IS NOT NULL
                            AND     V_ACK_MAPPING_EC.UNIQUE_REF_ID IS NULL
                            AND     V_ENTITY_CODE               <> V_CLIENT_RECORD.LEGAL_ID
                            THEN

                              V_ENV_INFO_TRACE.USER_MESSAGE :=  'ENTERED 8TH CONDITION: ' || PROC_ACK_FILE_DETAIL.RECORD_NO || 'PROC_ACK_FILE_DETAIL.REF_NO :' || PROC_ACK_FILE_DETAIL.REF_NO || ' PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID :' || PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID || ' V_ENTITY_CODE: ' || V_ENTITY_CODE || ' V_CLIENT_RECORD.LEGAL_ID : ' || V_CLIENT_RECORD.LEGAL_ID;
                                PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);

                                V_STATUS_MSG := ACK_FILE_GLOBAL_VARS.EXIST_DIF_REF_ID_ENT_NOT_MATCH;
                                RETURN_STATUS   :=  PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_REJECT (PROC_ACK_FILE_DETAIL.RECORD_NO,PROC_ACK_FILE_NAME.FILE_NAME,P_SEQ_NUM, V_STATUS_MSG);


                                IF RETURN_STATUS <> DECLARATION_CST.OK
                                    THEN
                                        V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR REURNED BY PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_REJECT ';
                                        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                                    RETURN (RETURN_STATUS);

                                END IF;
                            */ -- moved before 6
                            END IF;

                            EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                                                
                                BEGIN
                                    
                                    V_ACK_MAPPING_UR := NULL;  -- AJHAR20231109
                                    V_ACK_MAPPING_EC := NULL;  -- AJHAR20231109
                                    
                                    SELECT  *
                                    INTO    V_ACK_MAPPING_UR
                                    FROM    ACK_MAPPING_TABLE A
                                    WHERE   A.UNIQUE_REF_ID=PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID
                                    AND ROWNUM = 1; --AJHAR 20230906
                                EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    V_ENV_INFO_TRACE.USER_MESSAGE :=  'NO DATA FOUND IN ACK_MAPPING_TABLE FOR UNIQUE REF ID: ' || PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID;
                                    PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                                END;                                                               
                                
                                V_ENV_INFO_TRACE.USER_MESSAGE :=  'NO DATA FOUND - CONDITION 1 TO 4 ' ||  V_ENTITY_CODE || ' ' || V_CLIENT_RECORD.LEGAL_ID;
                                PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                                                                                                
                                /*START AJHAR20231108*/
                                BEGIN
                                    IF TRIM(PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID) = 'NOT FOUND' AND   V_ACK_MAPPING_EC.REF_NO        IS NULL
                                    THEN

                                        V_ENV_INFO_TRACE.USER_MESSAGE :=  'UNIQUE REF ID IS NOT FOUND FOR REF NO ' ||PROC_ACK_FILE_DETAIL.REF_NO;
                                        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);

                                        V_STATUS_MSG := ACK_FILE_GLOBAL_VARS.UNIQUE_REF_ID_NOT_FOUND;

                                        RETURN_STATUS   :=  PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_REJECT (PROC_ACK_FILE_DETAIL.RECORD_NO,PROC_ACK_FILE_NAME.FILE_NAME,P_SEQ_NUM, V_STATUS_MSG);

                                        IF RETURN_STATUS <> DECLARATION_CST.OK
                                        THEN
                                            V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR REURNED BY PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_REJECT ';
                                            PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                                            RETURN (RETURN_STATUS);
                                        END IF;

                                        CONTINUE;

                                    END IF;
                                END;
                                /*END AJHAR20231108*/

                                /*1. REF_NO, UNIQUE_REF_ID NOT IN ACK_MAPPING_TABLE AND ENTITY_CODE EQUAL LEGAL_ID IN CLIENT TABLE*/
                                IF  NVL(V_ENTITY_CODE,'X')               = NVL(V_CLIENT_RECORD.LEGAL_ID, 'X')  --AJHAR 20230907
                                AND V_ACK_MAPPING_EC.REF_NO        IS NULL
                                --AND V_ACK_MAPPING_EC.UNIQUE_REF_ID IS NULL
                                AND V_ACK_MAPPING_UR.UNIQUE_REF_ID IS NULL  --AJHAR 20230906
                                THEN

                                    V_ENV_INFO_TRACE.USER_MESSAGE :=  'NO DATA FOUND - CONDITION 1';
                                    PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);

                                    RETURN_STATUS   :=  PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_MAPPING_TABLE (PROC_ACK_FILE_DETAIL.RECORD_NO,PROC_ACK_FILE_NAME.FILE_NAME,P_SEQ_NUM);

                                    IF RETURN_STATUS = DECLARATION_CST.OK
                                    THEN
                                        V_STATUS_MSG := ACK_FILE_GLOBAL_VARS.NEW_ENT_MATCH;

                                        RETURN_STATUS   :=  PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_SUCCESS (PROC_ACK_FILE_DETAIL.RECORD_NO,PROC_ACK_FILE_NAME.FILE_NAME,P_SEQ_NUM,V_STATUS_MSG);

                                        IF RETURN_STATUS <> DECLARATION_CST.OK
                                        THEN
                                            V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR REURNED BY PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_SUCCESS ';
                                            PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                                        RETURN (RETURN_STATUS);
                                        END IF;

                                    ELSIF RETURN_STATUS <> DECLARATION_CST.OK
                                    THEN
                                            V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR RETURNED BY PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_MAPPING_TABLE ';
                                            PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                                            RETURN (RETURN_STATUS);
                                    END IF;                               
                        
                                
                                --/* 2. REF_NO, UNIQUE_REF_ID NOT IN ACK_MAPPING_TABLE AND ENTITY_CODE NOT EQUAL LEGAL_ID IN CLIENT TABLE --
                                ELSIF NVL(V_ENTITY_CODE,'X')               != NVL(V_CLIENT_RECORD.LEGAL_ID, 'X')    --AJHAR 20230907
                                AND   V_ACK_MAPPING_EC.REF_NO        IS NULL
                                --AND   V_ACK_MAPPING_EC.UNIQUE_REF_ID IS NULL
                                AND V_ACK_MAPPING_UR.UNIQUE_REF_ID IS NULL  --AJHAR 20230906
                                THEN

                                    V_ENV_INFO_TRACE.USER_MESSAGE :=  'NO DATA FOUND - CONDITION 2';
                                    PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);


                                    RETURN_STATUS   :=  PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_MAPPING_TABLE (PROC_ACK_FILE_DETAIL.RECORD_NO,PROC_ACK_FILE_NAME.FILE_NAME,P_SEQ_NUM);

                                    IF RETURN_STATUS = DECLARATION_CST.OK
                                    THEN
                                        V_STATUS_MSG := ACK_FILE_GLOBAL_VARS.NEW_ENT_NOT_MATCH;
                                        RETURN_STATUS   :=  PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_SUCCESS (PROC_ACK_FILE_DETAIL.RECORD_NO,PROC_ACK_FILE_NAME.FILE_NAME,P_SEQ_NUM,V_STATUS_MSG);

                                        IF RETURN_STATUS <> DECLARATION_CST.OK
                                        THEN
                                            V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR REURNED BY PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_SUCCESS ';
                                            PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                                        RETURN (RETURN_STATUS);

                                        END IF;

                                    ELSIF RETURN_STATUS <> DECLARATION_CST.OK
                                    THEN
                                        V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR REURNED BY PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_MAPPING_TABLE ';
                                        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                                    RETURN (RETURN_STATUS);

                                    END IF;                                                                    

                                /* 3. REF_NO NOT IN ACK_MAPPING_TABLE, UNIQUE_REF_ID IN ACK_MAPPING_TABLE AND ENTITY_CODE EQUAL LEGAL_ID IN CLIENT TABLE */
                                ELSIF
                                --START AJHAR 20230905
                                V_ACK_MAPPING_EC.REF_NO                     IS NULL    --AJHAR 20230901
                                --AND PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID      = V_ACK_MAPPING_EC.UNIQUE_REF_ID
                                AND NVL(PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID, 'X')      = NVL(V_ACK_MAPPING_UR.UNIQUE_REF_ID, 'X')  --AJHAR 20230907
                                --END AJHAR 20230905
                                AND    NVL(V_ENTITY_CODE,'X')               = NVL(V_CLIENT_RECORD.LEGAL_ID, 'X')    --AJHAR 20230907
                                THEN

                                    V_ENV_INFO_TRACE.USER_MESSAGE :=  'NO DATA FOUND - CONDITION 3';

                                    PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);

                                    RETURN_STATUS   :=  PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_MAPPING_TABLE (PROC_ACK_FILE_DETAIL.RECORD_NO,PROC_ACK_FILE_NAME.FILE_NAME,P_SEQ_NUM);

                                    IF RETURN_STATUS = DECLARATION_CST.OK
                                    THEN
                                        V_STATUS_MSG := ACK_FILE_GLOBAL_VARS.NEW_REF_ID_ENT_MATCH;

                                        RETURN_STATUS   :=  PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_SUCCESS (PROC_ACK_FILE_DETAIL.RECORD_NO,PROC_ACK_FILE_NAME.FILE_NAME,P_SEQ_NUM,V_STATUS_MSG);

                                        IF RETURN_STATUS <> DECLARATION_CST.OK
                                        THEN
                                            V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR RETURNED BY PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_SUCCESS ';
                                            PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                                        RETURN (RETURN_STATUS);
                                        END IF;


                                    ELSIF RETURN_STATUS <> DECLARATION_CST.OK
                                    THEN
                                        V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR REURNED BY PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_MAPPING_TABLE ';
                                        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                                    RETURN (RETURN_STATUS);

                                    END IF;
                                                                    
                                
                                /* 4. REF_NO NOT IN ACK_MAPPING_TABLE UNIQUE_REF_ID IN ACK_MAPPING_TABLE AND ENTITY_CODE NOT EQUAL LEGAL_ID IN CLIENT TABLE */
                                
                                ELSIF
                                --START AJHAR 20230905
                                V_ACK_MAPPING_EC.REF_NO                     IS NULL    --AJHAR 20230901
                                --AND PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID      = V_ACK_MAPPING_EC.UNIQUE_REF_ID
                                AND NVL(PROC_ACK_FILE_DETAIL.UNIQUE_REF_ID, 'X')      = NVL(V_ACK_MAPPING_UR.UNIQUE_REF_ID, 'X')    --AJHAR 20230907
                                --END AJHAR 20230905
                                AND NVL(V_ENTITY_CODE,'X')               != NVL(V_CLIENT_RECORD.LEGAL_ID, 'X')    --AJHAR 20230907
                                THEN

                                    V_ENV_INFO_TRACE.USER_MESSAGE :=  'NO DATA FOUND - CONDITION 4';
                                    PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);

                                    RETURN_STATUS   :=  PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_MAPPING_TABLE (PROC_ACK_FILE_DETAIL.RECORD_NO,PROC_ACK_FILE_NAME.FILE_NAME,P_SEQ_NUM);

                                    IF RETURN_STATUS = DECLARATION_CST.OK
                                    THEN
                                        V_STATUS_MSG := ACK_FILE_GLOBAL_VARS.NEW_REF_ID_ENT_NOT_MATCH;
                                        RETURN_STATUS   :=  PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_SUCCESS (PROC_ACK_FILE_DETAIL.RECORD_NO,PROC_ACK_FILE_NAME.FILE_NAME,P_SEQ_NUM,V_STATUS_MSG);

                                        IF RETURN_STATUS <> DECLARATION_CST.OK
                                        THEN
                                            V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR RETURNED BY PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_FILE_SUCCESS ';
                                            PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                                        RETURN (RETURN_STATUS);
                                        END IF;

                                    ELSIF RETURN_STATUS <> DECLARATION_CST.OK
                                    THEN
                                        V_ENV_INFO_TRACE.USER_MESSAGE :=  'ERROR REURNED BY PCRD_ACKNOWLEDGEMENT_FILE.PUT_ACK_MAPPING_TABLE ';
                                        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                                    RETURN (RETURN_STATUS);
                                    END IF;                                                                                                        
                            END IF;
                    END;
            END LOOP;
        END LOOP;

    RETURN (RETURN_STATUS);
EXCEPTION WHEN OTHERS
THEN
    V_ENV_INFO_TRACE.ERROR_CODE     :=  GLOBAL_VARS_ERRORS.ORACLE_ERROR;
    V_ENV_INFO_TRACE.USER_MESSAGE   :=  ' OTHERS ERROR:  ' || SUBSTR (SQLERRM, 1, 100);
    PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
    RETURN  DECLARATION_CST.ERROR;
END PROCESS_ACK_FILE_DETAIL_TABLE;
/* END - MH 23012023 -- ADDED FUNCTION PROCESS_ACK_FILE_DETAIL_TABLE - END */
--------------------------------------------------------------------------------------
FUNCTION    PROC_ACK_FILE_PROC_HEADER      (   P_BUSINESS_DATE           IN   DATE,
                                                   P_TASK_NAME               IN   PCARD_TASKS.TASK_NAME%TYPE,
                                                   P_SEQ_NUM                 IN   ACK_FILE_BUFFER.SEQUENCE_NUMBER%TYPE)
                                               RETURN PLS_INTEGER  IS

V_ENV_INFO_TRACE                GLOBAL_VARS.ENV_INFO_TRACE_TYPE;
RETURN_STATUS                   PLS_INTEGER;
V_COUNT                             PLS_INTEGER;



CURSOR CUR_ACK_FILE_HEADER
    IS  SELECT   *
        FROM     ACK_FILE_HEADER
        WHERE SEQUENCE_NUMBER=P_SEQ_NUM ;
        --FOR      UPDATE;
BEGIN
    --------------------------------------------------------------------
    V_ENV_INFO_TRACE.BUSINESS_DATE  :=  P_BUSINESS_DATE;
    V_ENV_INFO_TRACE.USER_NAME      :=  GLOBAL_VARS.USER_NAME;
    V_ENV_INFO_TRACE.MODULE_CODE    :=  GLOBAL_VARS.ML_CREDIT_REVOLVING;
    V_ENV_INFO_TRACE.PACKAGE_NAME   :=  $$PLSQL_UNIT;
    V_ENV_INFO_TRACE.FUNCTION_NAME  :=  'PROC_ACK_FILE_PROC_HEADER';
    V_ENV_INFO_TRACE.LANG           :=  GLOBAL_VARS.LANG;
    --------------------------------------------------------------------

    PCRD_ERRORS.TASK_NAME := P_TASK_NAME;


    FOR ENR_ACK_FILE_HEADER IN CUR_ACK_FILE_HEADER
    LOOP
        -- FILE_NAME
     IF ENR_ACK_FILE_HEADER.FILE_NAME IS NULL
    THEN
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR IN FILE DATA. TAG FILE_NAME IN HEADER IS NULL';
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN  DECLARATION_CST.ERROR;
    END IF;

    -- LOAD_FLAG
     IF ENR_ACK_FILE_HEADER.LOAD_FLAG IS NULL
    THEN
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR IN FILE DATA. TAG LOAD_FLAG IN HEADER IS NULL';
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN  DECLARATION_CST.ERROR;
    END IF;

     IF ENR_ACK_FILE_HEADER.LOAD_FLAG NOT IN ('N','Y')
    THEN
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR IN FILE DATA. TAG LOAD_FLAG IN HEADER - BAD VALUE : ['||ENR_ACK_FILE_HEADER.LOAD_FLAG||']';
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN  DECLARATION_CST.ERROR;
    END IF;

    -- GROUP
     IF ENR_ACK_FILE_HEADER.GROUP_ IS NULL
    THEN
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR IN FILE DATA. TAG GROUP IN HEADER IS NULL';
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN  DECLARATION_CST.ERROR;
    END IF;

    -- SUBMITTED_BY
     IF ENR_ACK_FILE_HEADER.SUBMITTED_BY IS NULL
    THEN
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR IN FILE DATA. TAG SUBMITTED_BY IN HEADER IS NULL';
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN  DECLARATION_CST.ERROR;
    END IF;

     -- SUBMISSION_DATE
     IF ENR_ACK_FILE_HEADER.SUBMISSION_DATE IS NULL
    THEN
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR IN FILE DATA. TAG SUBMISSION_DATE IN HEADER IS NULL';
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN  DECLARATION_CST.ERROR;
    ELSIF NOT PCRD_CB_TOOLS.IS_DATE(ENR_ACK_FILE_HEADER.SUBMISSION_DATE,'DD/MM/YYYY HH24:MI:SS')
    THEN
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR IN FILE DATA. TAG SUBMISSION_DATE IN HEADER IS NOT DATE';
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN  DECLARATION_CST.ERROR;
    END IF;

     -- LOAD_DATE
     IF ENR_ACK_FILE_HEADER.LOAD_DATE IS NULL
    THEN
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR IN FILE DATA. TAG LOAD_DATE IN HEADER IS NULL';
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN  DECLARATION_CST.ERROR;
    ELSIF NOT PCRD_CB_TOOLS.IS_DATE(ENR_ACK_FILE_HEADER.LOAD_DATE,'DD/MM/YYYY HH24:MI:SS')
    THEN
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR IN FILE DATA. TAG LOAD_DATE IN HEADER IS NOT DATE';
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN  DECLARATION_CST.ERROR;
    END IF;

    -- NO_OF_RECORDS
     IF ENR_ACK_FILE_HEADER.NO_OF_RECORDS IS NULL
    THEN
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR IN FILE DATA. TAG NO_OF_RECORDS IN HEADER IS NULL';
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN  DECLARATION_CST.ERROR;
    ELSIF NOT PCRD_CB_TOOLS.IS_NUMERIC (ENR_ACK_FILE_HEADER.NO_OF_RECORDS)
    THEN
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR IN FILE DATA. TAG NO_OF_RECORDS IN HEADER IS NOT NUMERIC';
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN  DECLARATION_CST.ERROR;
    END IF;

    -- VALID_RECORDS
     IF ENR_ACK_FILE_HEADER.VALID_RECORDS IS NULL
    THEN
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR IN FILE DATA. TAG VALID_RECORDS IN HEADER IS NULL';
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN  DECLARATION_CST.ERROR;
    ELSIF NOT PCRD_CB_TOOLS.IS_NUMERIC (ENR_ACK_FILE_HEADER.VALID_RECORDS)
    THEN
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR IN FILE DATA. TAG VALID_RECORDS IN HEADER IS NOT NUMERIC';
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN  DECLARATION_CST.ERROR;
    END IF;
    -----------------------------------------------------------------------------------------------------------------
    -- XML TAG VALIDATION --> ACK_FILE_DETAIL
    -----------------------------------------------------------------------------------------------------------------
    BEGIN
        SELECT  COUNT(1)
        INTO    V_COUNT
        FROM    ACK_FILE_DETAIL
        WHERE SEQUENCE_NUMBER=ENR_ACK_FILE_HEADER.SEQUENCE_NUMBER AND INTERNAL_FILE_NAME=ENR_ACK_FILE_HEADER.FILE_NAME;
    EXCEPTION WHEN OTHERS
    THEN
        V_ENV_INFO_TRACE.ERROR_CODE     :=  GLOBAL_VARS_ERRORS.ERROR_SELECT_COUNT;
        V_ENV_INFO_TRACE.PARAM1         :=  'ACK_FILE_DETAIL';
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR WHEN SELECTING COUNT(*) FROM TABLE ACK_FILE_DETAIL'
                                        ||  ' SEQUENCE NUMBER : '      || ENR_ACK_FILE_HEADER.SEQUENCE_NUMBER
                                        ||  ' FILE NAME : '            || ENR_ACK_FILE_HEADER.FILE_NAME;
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN  DECLARATION_CST.ERROR;
    END;

    IF   ( V_COUNT <> ENR_ACK_FILE_HEADER.NO_OF_RECORDS AND ACK_FILE_GLOBAL_VARS.ENABLE_CTRL = 'Y'  )
    THEN
        V_ENV_INFO_TRACE.ERROR_CODE     :=  GLOBAL_VARS_ERRORS.NB_RECORD_DIFF_FILE_TRAILER;
        V_ENV_INFO_TRACE.USER_MESSAGE   :=  'ERROR IN FILE DATA. THE NUMBER OF RECORDS IS NOT THAT MENTIONED '
                                        ||  'IN THE FILE HEADER.'
                                        ||  ' SEQUENCE NUMBER : '      || ENR_ACK_FILE_HEADER.SEQUENCE_NUMBER
                                        ||  ' FILE NAME : '            || ENR_ACK_FILE_HEADER.FILE_NAME;
        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
        RETURN( DECLARATION_CST.ERROR );
    END IF;



    END LOOP;

    RETURN  DECLARATION_CST.OK;

EXCEPTION WHEN OTHERS
THEN
    V_ENV_INFO_TRACE.ERROR_CODE     :=  GLOBAL_VARS_ERRORS.ORACLE_ERROR;
    V_ENV_INFO_TRACE.USER_MESSAGE   :=  ' OTHERS ERROR:  ' || SUBSTR (SQLERRM, 1, 100);
    PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
    RETURN  DECLARATION_CST.ERROR;
END PROC_ACK_FILE_PROC_HEADER;

END PCRD_ACKNOWLEDGEMENT_FILE;
/

-- Grants for Package Body
GRANT EXECUTE ON pcrd_acknowledgement_file TO icps_power_cim
/


-- End of DDL Script for Package Body POWERIOV3.PCRD_ACKNOWLEDGEMENT_FILE

