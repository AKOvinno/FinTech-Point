-- Start of DDL Script for Package Body POWERIOV3.PCRD_ICPS_GEN_MCBI_FILE
-- Generated 21-Nov-2023 09:55:57 from POWERIOV3@(DESCRIPTION =(ADDRESS_LIST =(ADDRESS = (PROTOCOL = TCP)(HOST = 172.17.8.90)(PORT = 1530)))(CONNECT_DATA =(SERVICE_NAME = afcv3)))

CREATE OR REPLACE 
PACKAGE BODY pcrd_icps_gen_mcbi_file
IS

FUNCTION    CHECK_SHADOW_ACCOUNT            (   p_business_date                 IN          DATE,
                                                p_pcard_tasks_record            IN          PCARD_TASKS%ROWTYPE,
                                                p_shadow_account_record         IN          SHADOW_ACCOUNT%ROWTYPE,
                                                p_eligible_account              OUT NOCOPY  BOOLEAN  ,
                                                p_record_status                 OUT NOCOPY  ICPS_MCIB_FILE.record_status%TYPE)
                                                RETURN PLS_INTEGER IS


v_pcrd_file_processing_rec      PCRD_FILE_PROCESSING%ROWTYPE;
v_env_info_trace                global_vars.env_info_trace_type;
Return_Status                   PLS_INTEGER;
v_count                         NUMBER;
v_sum_amount                    CR_TRANSACTION.billing_amount%TYPE ;

BEGIN
    v_env_info_trace.business_date  :=  p_business_date;
    v_env_info_trace.user_name      :=  global_vars.USER_NAME;
    v_env_info_trace.module_code    :=  global_vars.ML_CREDIT_REVOLVING;
    v_env_info_trace.lang           :=  global_vars.LANG;
    v_env_info_trace.package_name   :=  'PCRD_ICPS_GEN_MCBI_FILE';
    v_env_info_trace.function_name  :=  'CHECK_SHADOW_ACCOUNT';

    IF  p_pcard_tasks_record.parameter_V1_data = 'F'
    THEN
        p_eligible_account  :=  TRUE;
        p_record_status     :=  'N' ;
    ELSE
        IF  p_shadow_account_record.AGREEMENT_DATE      =    p_business_date
        THEN
            p_record_status     :=  'N' ;
        ELSE
            p_record_status     :=  'A' ;
        END IF ;

        --  Ctrl 1 le compte change de status depuis le dernier envoi
        --  =========================================================
        IF  p_shadow_account_record.administrative_status_date >=   p_business_date
        THEN
            p_eligible_account := TRUE;
            RETURN declaration_cst.OK;
        END IF;

        --  Ctrl 2 le compte change de limite depuis le dernier envoi
        --  =========================================================
        IF  p_shadow_account_record.former_credit_limit_d         >= p_business_date
        OR  p_shadow_account_record.former_cash_transfer_limit_d  >= p_business_date
        THEN
            p_eligible_account := TRUE;
            RETURN declaration_cst.OK;
        END IF;

        --  Ctrl 3 le compte change de status unpaid depuis le dernier envoi
        --  ================================================================
        IF p_shadow_account_record.unpaid_status_date   >= p_business_date
        THEN
            p_eligible_account := TRUE;
            RETURN declaration_cst.OK;
        END IF;

        --  Ctrl 4 le compte change d'outstanding balance depuis le dernier envoi
        --  =====================================================================
        BEGIN
        -- If the total amount less than 1 , the record should not be sent.
            SELECT  COUNT(*) , SUM(BILLING_AMOUNT )
            INTO    v_count  , v_sum_amount
            FROM    V_CR_TRANSACTION_CAH
            WHERE   shadow_account_nbr      =   p_shadow_account_record.shadow_account_nbr
                 AND posting_date           >=   p_business_date;

        EXCEPTION
        WHEN OTHERS THEN
            v_env_info_trace.user_message   :=  'OTHERS ERROR SELECT V_CR_TRANSACTION_CAH : '   ||  SUBSTR(SQLERRM,1,100)
                                            || ', S/A NUMBER : '                                ||  p_shadow_account_record.shadow_account_nbr
                                            || ', LAST_PROCESSING_DATE : '                      ||  TO_CHAR ( p_business_date , 'DD/MM/YYYY');
            PCRD_GENERAL_TOOLS.PUT_TRACES ( v_env_info_trace, 1000 );
            RETURN declaration_cst.ERROR;
        END;
        IF v_count > 0  AND v_sum_amount >=1

        THEN
            p_eligible_account := TRUE;
            RETURN declaration_cst.OK;
        END IF;
    END IF;

    RETURN declaration_cst.OK;

EXCEPTION
WHEN    OTHERS  THEN
    v_env_info_trace.user_message   :=  'OTHERS ERROR : '   ||  SUBSTR(SQLERRM,1,100);
    PCRD_GENERAL_TOOLS.PUT_TRACES    (   v_env_info_trace, 1000 );
    RETURN declaration_cst.ERROR;
END CHECK_SHADOW_ACCOUNT;

---------------------------------------------------------------------------------------------------------
FUNCTION    MAIN_MCIB_FILE (   p_business_date                 IN          DATE,
                               p_task_name                     IN          PCARD_TASKS.task_name%TYPE )
                               RETURN  PLS_INTEGER IS


v_env_info_trace                global_vars.env_info_trace_type;
Return_Status                   PLS_INTEGER;
v_nb_records                    NUMBER(6);
v_pcard_tasks_record            PCARD_TASKS%ROWTYPE;
v_file_seq                      NUMBER:= 100;
v_pcard_tasks_ht_record         pcard_tasks_ht%ROWTYPE;
v_first_unpaid_date             shadow_account.first_unpaid_date%type;
BEGIN
   v_env_info_trace.user_name      :=  global_vars.USER_NAME;
   v_env_info_trace.module_code    :=  global_vars.ML_MISC;
   v_env_info_trace.package_name   :=  'PCRD_ICPS_GEN_MCBI_FILE';
   v_env_info_trace.function_name  :=  'MAIN_MCIB_FILE';
   v_env_info_trace.lang           :=  global_vars.LANG;


   Return_Status := PCRD_GET_DATA_ADMIN_ROWS.GET_PCARD_TASKS   (   p_task_name,
                                                                    v_pcard_tasks_record );
   IF Return_Status <> declaration_cst.OK
   THEN
        v_env_info_trace.user_message   :=  'ERROR RETURNED BY PCRD_GET_DATA_ADMIN_ROWS.GET_PCARD_TASKS'
                                        ||  ', TASK NAME : ' || p_task_name;
        PCRD_GENERAL_TOOLS.PUT_TRACES ( v_env_info_trace , 100 );
        RETURN Return_Status;
   END IF;


   BEGIN
        SELECT      *
        INTO        v_pcard_tasks_ht_record
        FROM        pcard_tasks_ht
        WHERE       task_name       =   v_pcard_tasks_record.task_name
            AND     business_date   =   p_business_date
            AND     status          <> 'P'
            AND     start_date      IN  (   SELECT  MAX(    start_date  )
                                            FROM        pcard_tasks_ht
                                            WHERE       task_name       =   v_pcard_tasks_record.task_name
                                            AND     business_date   =   p_business_date
                                            AND     status          <> 'P'  )
            AND ROWNUM = 1 ;

    EXCEPTION WHEN NO_DATA_FOUND
    THEN
            v_env_info_trace.user_message   :=  'NO DATA FOUND FOR PCARD_TASKS_HT ' || p_business_date;
        PCRD_GENERAL_TOOLS.PUT_TRACES ( v_env_info_trace , 100 );

        v_pcard_tasks_ht_record.status      :=  'U' ;
    WHEN OTHERS
    THEN
        v_env_info_trace.user_message   :=  'ERROR WHILE SELECTING FROM  PCARD_TASKS_HT := '|| TO_CHAR(p_business_date , 'DD/MM/YYYY')
                                        ||  ', TASK NAME : ' || p_task_name;
        PCRD_GENERAL_TOOLS.PUT_TRACES ( v_env_info_trace , 100 );
        RETURN declaration_cst.NOK ;
    END;

    IF      v_pcard_tasks_ht_record.status             =   'S'
        AND v_pcard_tasks_ht_record.business_date      =   p_business_date
    THEN
        v_env_info_trace.user_message   :=  'Batch Already Processed for this date := '|| TO_CHAR(p_business_date , 'DD/MM/YYYY')
                                        ||  ', TASK NAME : ' || v_pcard_tasks_ht_record.task_name;
        PCRD_GENERAL_TOOLS.PUT_TRACES ( v_env_info_trace , 100 );
        RETURN declaration_cst.NOK ;
    END IF;


    Return_Status :=    PCRD_ICPS_GEN_MCBI_FILE.FUNC_MCIB_OUTPUT_FILE  (    p_business_date,
                                                                            v_pcard_tasks_record );

    IF Return_Status <> declaration_cst.OK
    THEN
        v_env_info_trace.user_message   :=  'ERROR RETURNED BY PCRD_ICPS_GEN_MCBI_FILE.FUNC_MCIB_OUTPUT_FILE';
        PCRD_GENERAL_TOOLS.PUT_TRACES ( v_env_info_trace , 200 );
        ROLLBACK;
        RETURN Return_Status;
    END IF;


    v_file_seq                      :=  100;

    Return_Status   :=      PCRD_ICPS_GEN_MCBI_FILE.GENERATE_FILE  (    p_business_date,        --NB30Aug2022 Date in filename generation
                                                                                                                                                v_file_seq );

    IF Return_Status <> declaration_cst.OK
    THEN
        v_env_info_trace.user_message   :=  'ERROR RETURNED BY PCRD_ICPS_GEN_MCBI_FILE.GENERATE_FILE';
        PCRD_GENERAL_TOOLS.PUT_TRACES ( v_env_info_trace , 300 );
        RETURN Return_Status;
    END IF;

    RETURN declaration_cst.OK;

EXCEPTION
WHEN    OTHERS  THEN
    v_env_info_trace.user_message   :=  'OTHERS ERROR : '   ||  SUBSTR(SQLERRM,1,100);
    PCRD_GENERAL_TOOLS.PUT_TRACES    (   v_env_info_trace , 400 );
    RETURN declaration_cst.ERROR;
END MAIN_MCIB_FILE;
----------------------------------------------------------------------------------------------------------------
FUNCTION    FUNC_MCIB_OUTPUT_FILE            (   p_business_date                 IN             DATE,
                                                 p_pcard_tasks_record            IN             pcard_tasks%ROWTYPE )
                                                RETURN PLS_INTEGER  IS
                                               --- PRAGMA AUTONOMOUS_TRANSACTION; --BJH18022019

v_env_info_trace                    global_vars.env_info_trace_type;
Return_Status                       PLS_INTEGER;
v_currency_table_record             CURRENCY_TABLE%ROWTYPE;
v_client_addendum_record            CLIENT_ADDENDUM%ROWTYPE;
v_client_record                     CLIENT%ROWTYPE;
v_card_record                       CARD%ROWTYPE;
v_basic_card_record                 CARD%ROWTYPE;
v_pcard_tasks_record                PCARD_TASKS%ROWTYPE;
v_pcard_tasks_jobs_rec              PCARD_TASKS_JOBS%ROWTYPE;
v_eligible_account                  BOOLEAN;
v_owner_category                    owner_list.owner_category%TYPE;
v_icps_mcib_file                    ICPS_MCIB_FILE%ROWTYPE ;
v_record_status                     ICPS_MCIB_FILE.record_status%TYPE ;
v_country_record                    COUNTRY%ROWTYPE;
v_addresses_table_record            ADDRESSES_TABLE%ROWTYPE ;
v_error_code                        POWERCARD_FORMS_MESSAGE.message_number%TYPE;
v_cr_term_unpaid_tmp_rec            cr_global_vars.cr_term_unpaid_tmp_type;
v_cr_profile_record                 CR_PROFILE%ROWTYPE;
v_last_date                         PCARD_TASKS_HT.start_date%TYPE ; --BJH18022019
v_cr_term_rec                       CR_TERM%ROWTYPE; --BJH25022019
v_corporate_card_record             CARD%ROWTYPE; --BJH30052019
v_first_unpaid_date                 shadow_account.first_unpaid_date%type;
v_sum_supl_acc                      shadow_account.closing_balance_purchase%type;---MAK17122019--add supplementary balance for corporate accounts
v_next_processing_date              cycle_cutoff_list.next_processing_date%type;
v_no_days                           NUMBER; ---YM18082020 TYPE CLASS CHANGE REQUEST
v_ack_mapping                       ack_mapping_table.unique_ref_id%TYPE; -- MH30032023


CURSOR  cur_shadow_account  (p_last_date IN    PCARD_TASKS_HT.start_date%TYPE     )  IS

    /*SELECT      *
    FROM        SHADOW_ACCOUNT
    WHERE       administrative_status <> '7'
    AND SHADOW_ACCOUNT_NBR NOT IN (SELECT SHADOW_ACCOUNT_NBR FROM shadow_account_exclusion)
    AND SHADOW_ACCOUNT_NBR NOT IN (SELECT SHADOW_ACCOUNT_NBR FROM shadow_account_write_off_att)---YM18082020  to remove WO accounts to be reported again
    --AND SHADOW_ACCOUNT_NBR NOT IN ('CRD5135801','CRD5113806')--IBM18092020 Crash 119118 LEGAL ID CLIENT is null
    AND ((date_Create > p_last_date )
        OR (date_modif > p_last_date )) --BJH18022019

    ORDER BY    shadow_account_nbr ;    */

    SELECT      *
    FROM        SHADOW_ACCOUNT
    WHERE       administrative_status <> '7'
    AND SHADOW_ACCOUNT_NBR NOT IN (SELECT SHADOW_ACCOUNT_NBR FROM shadow_account_exclusion)
    AND SHADOW_ACCOUNT_NBR NOT IN (SELECT SHADOW_ACCOUNT_NBR FROM shadow_account_write_off_att)---YM18082020  to remove WO accounts to be reported again
    --AND SHADOW_ACCOUNT_NBR NOT IN ('CRD5135801','CRD5113806')--IBM18092020 Crash 119118 LEGAL ID CLIENT is null
    --AND SHADOW_ACCOUNT_NBR NOT IN ('CRD5133429','CRD5131714')--ANU28052023 Crash 0346394393 LEGAL ID CLIENT is null --DHACHA30052023
    AND ((date_Create > p_last_date )
        OR (date_modif > p_last_date )) --BJH18022019

    ORDER BY    shadow_account_nbr ;






BEGIN

    v_env_info_trace.business_date  :=  p_business_date;
    v_env_info_trace.user_name      :=  global_vars.USER_NAME;
    v_env_info_trace.module_code    :=  global_vars.ML_CREDIT_REVOLVING;
    v_env_info_trace.lang           :=  global_vars.LANG;
    v_env_info_trace.package_name   :=  'PCRD_ICPS_GEN_MCBI_FILE';
    v_env_info_trace.function_name  :=  'FUNC_MCIB_OUTPUT_FILE';


    Return_Status := PCRD_GENERAL_TOOLS.TRUNCATE_TABLE ( 'ICPS_MCIB_FILE' );

    IF  Return_Status <> declaration_cst.OK
    THEN
        v_env_info_trace.user_message := ':ERROR RETURNED BY PCRD_GENERAL_TOOLS.TRUNCATE_TABLE ICPS_MCIB_FILE ';
        PCRD_GENERAL_TOOLS.PUT_TRACES (v_env_info_trace,10);
        RETURN(Return_Status);
    END IF;

--BJH18022019
  BEGIN

    --TO GENERATE FULL

    IF p_business_date = '23-APR-1910'
    THEN
        SELECT NVL(MIN(start_date),TO_DATE('01/01/2000','DD/MM/RRRR HH24MISS'))
        INTO v_last_date
        FROM PCARD_TASKS_HT
        WHERE task_name = p_pcard_tasks_record.task_name
            AND status = global_vars.TASK_ENDED_SUCCESSFULLY;

    ELSE
        SELECT NVL(MAX(start_date),TO_DATE('01/01/2000','DD/MM/RRRR HH24MISS'))
        INTO v_last_date
        FROM PCARD_TASKS_HT
        WHERE task_name = p_pcard_tasks_record.task_name
            AND status = global_vars.TASK_ENDED_SUCCESSFULLY;

    END IF ;
    EXCEPTION WHEN OTHERS
    THEN
        v_env_info_trace.user_message := ':ERROR DURING EXECUTION Select From PCARD_TASKS_HT, Task_name :'||p_pcard_tasks_record.task_name;
        PCRD_GENERAL_TOOLS.PUT_TRACES (v_env_info_trace,10);
        ROLLBACK;
        RETURN(declaration_cst.ERROR );
    END;
--BJH18022019

    FOR     v_shadow_account_record     IN  cur_shadow_account (v_last_date)
    LOOP
        v_icps_mcib_file        :=  NULL ;
        V_FIRST_UNPAID_DATE     := NULL;
        v_no_days := 0;  --RT26102020
       /* Return_Status   :=  PCRD_ICPS_GEN_MCBI_FILE.CHECK_SHADOW_ACCOUNT       (  p_business_date,
                                                                                  p_pcard_tasks_record,
                                                                                  v_shadow_account_record,
                                                                                  v_eligible_account ,
                                                                                  v_record_status );
        IF Return_Status <> declaration_cst.OK
        THEN
            v_env_info_trace.user_message   :=  'ERROR RETURNED BY PCRD_ICPS_GEN_MCBI_FILE.CHECK_SHADOW_ACCOUNT'
                                            ||  ', SHADOW_ACCOUNT_NBR : ' || v_shadow_account_record.shadow_account_nbr;
            PCRD_GENERAL_TOOLS.PUT_TRACES ( v_env_info_trace , 100 );
            RETURN Return_Status;
        END IF;*/
      ---YM18082020 - to remove WO accounts to be reported again
        IF  v_shadow_account_record.administrative_status IN ('5', '6','7','8','9')
        THEN
             --start Account closed with reason code Write Off Attorney should not be reported when balance becomes zero due to the write off.
            IF v_shadow_account_record.status_reason_code =  'WO'
            THEN
                IF trunc(v_shadow_account_record.administrative_status_date) =  trunc(p_business_date)
                THEN
                INSERT INTO shadow_account_write_off_att VALUES (V_SHADOW_ACCOUNT_RECORD.SHADOW_ACCOUNT_NBR ,V_SHADOW_ACCOUNT_RECORD.ADMINISTRATIVE_STATUS,V_SHADOW_ACCOUNT_RECORD.ADMINISTRATIVE_STATUS_DATE,USER, SYSDATE,NULL,NULL );
                END IF ;
            END IF;
        END IF;
        ---YM18082020 - to remove WO accounts to be reported again

        --start 20200423 Ihelp 0106721
        IF  v_shadow_account_record.administrative_status IN ('5', '6','7','8','9')
        THEN
             --start Account closed with reason code Write Off Attorney should not be reported when balance becomes zero due to the write off.
            IF v_shadow_account_record.status_reason_code =  'WO'
            THEN
                IF trunc(v_shadow_account_record.administrative_status_date) <>  trunc(p_business_date)
                THEN
                    GOTO NEXT_RECORD ;
                END IF ;
                 --end Account closed with reason code Write Off Attorney should not be reported when balance becomes zero due to the write off.
            ELSE
               --start ANTLAL Normal account closure (Not write off Attoney 'WO'): Account to be reported in the MCIB only once after closure with correct balance

                --check the unpaid status to see if account is regularized then report it
                IF v_shadow_account_record.f_unpaid_status <> v_shadow_account_record.unpaid_status
                AND v_shadow_account_record.unpaid_status = '0'
                AND v_shadow_account_record.unpaid_status_Date =  trunc(p_business_date)
                THEN
                    NULL ;
                ELSE
                    IF trunc(v_shadow_account_record.administrative_status_date) <>  trunc(p_business_date)
                    THEN
                        GOTO NEXT_RECORD ;
                    END IF ;
                END IF ;
                --end ANTLAL Normal account closure: Account to be reported in the MCIB only once after closure with correct balance
            END IF ;




        END IF ;


        --end  20200423 Ihelp 0106721

        --BJH24052019
        IF  v_shadow_account_record.corporate_id IS NOT NULL
            AND v_shadow_account_record.primary_shadow_account_nbr IS NOT NULL
        THEN
            GOTO NEXT_RECORD ;
        END IF;
        v_record_status         :=  'X';
        v_eligible_account      :=  TRUE ;

        IF  v_eligible_account
        THEN
            Return_Status   :=  PCRD_GET_PARAM_REVOLVING_ROWS.GET_CR_PROFILE   (    v_shadow_account_record.bank_code,
                                                                                    v_shadow_account_record.current_profile_code,
                                                                                    v_cr_profile_record,
                                                                                    TRUE);
            IF  Return_Status <> declaration_cst.OK
            THEN
                v_env_info_trace.user_message := 'ERROR RETURNED BY PCRD_GET_PARAM_REVOLVING_ROWS.GET_CR_PROFILE';
                PCRD_GENERAL_TOOLS.PUT_TRACES  (v_env_info_trace,$$PLSQL_LINE );
                ROLLBACK;
                RETURN (Return_Status);
            END IF;

            Return_Status := PCRD_REVOLVING_PROC_DATA_4.MANAGE_CR_TERM_UNPAID_TMP   (   p_business_date,
                                                                                        v_shadow_account_record,
                                                                                        v_cr_profile_record,
                                                                                        global_vars.NO,
                                                                                        v_cr_term_unpaid_tmp_rec);
            IF  Return_Status <> declaration_cst.OK
            THEN
                    v_env_info_trace.user_message   := 'ERROR RETURNED BY PCRD_REVOLVING_PROC_DATA_4.MANAGE_CR_TERM_UNPAID_TEMP'
                                                    || ', S/A NUMBER : '    || v_shadow_account_record.shadow_account_nbr;
                    PCRD_GENERAL_TOOLS.PUT_TRACES   ( v_env_info_trace , 900 );
                    ROLLBACK;
                    RETURN Return_Status;
            END IF;
            --BJH25022019
            Return_status   :=  PCRD_GET_DATA_REVOLVING_ROWS.GET_CR_TERM        (   v_shadow_account_record.shadow_account_nbr,
                                                                                    v_shadow_account_record.date_last_statement,
                                                                                    v_cr_term_rec);
            IF Return_status = declaration_cst.ERROR
            THEN
                    v_env_info_trace.user_message   :=  'ERROR RETURNED BY PCRD_GET_DATA_CARD_ROWS.GET_CR_TERM:'||v_shadow_account_record.shadow_account_nbr;
                    PCRD_GENERAL_TOOLS.PUT_TRACES (v_env_info_trace,$$PLSQL_LINE);
                    ROLLBACK;
                    RETURN (Return_status);
            END IF;
            --BJH25022019
            Return_Status   :=  PCRD_GET_DATA_CARD_ROWS.GET_CLIENT  (   v_shadow_account_record.client_code,
                                                                        v_client_record );
            IF Return_Status <> declaration_cst.OK
            THEN
                v_env_info_trace.user_message :=  'ERROR RETURN BY PCRD_GET_DATA_CARD_ROWS.GET_CLIENT CL:='  || v_shadow_account_record.client_code;
                PCRD_GENERAL_TOOLS.PUT_TRACES (v_env_info_trace,400);
                ROLLBACK;
                RETURN( Return_Status );
            END IF;


            IF  v_client_record.LEGAL_ID IS NULL
            THEN
                v_env_info_trace.user_message :=  'LEGAL ID IS NULL FOR CL:='  || v_shadow_account_record.client_code;
                PCRD_GENERAL_TOOLS.PUT_TRACES (v_env_info_trace,400);
                ROLLBACK;
                RETURN( declaration_cst.ERROR );
            END IF;

            --v_icps_mcib_file.entity_code            :=  v_client_record.LEGAL_ID ; --NHO18102021 CR for Company Entity Code


            BEGIN
                SELECT  owner_category
                INTO    v_owner_category
                FROM    OWNER_LIST
                WHERE   owner_code      =   v_shadow_account_record.owner_code ;
            EXCEPTION WHEN NO_DATA_FOUND
            THEN
                v_env_info_trace.user_message   :=  'NO DATA_FOUND WHILE SELECT FROM owner_list '|| v_shadow_account_record.owner_code ;
                PCRD_GENERAL_TOOLS.PUT_TRACES ( v_env_info_trace , 200 );
                ROLLBACK;
                RETURN  declaration_cst.NOK ;

            RETURN Return_Status;
            WHEN OTHERS
            THEN
                v_env_info_trace.user_message   :=  'ERROR WHILE SELECT FROM owner_list '|| v_shadow_account_record.owner_code ;
                PCRD_GENERAL_TOOLS.PUT_TRACES ( v_env_info_trace , 300 );
                ROLLBACK;
                RETURN  declaration_cst.NOK ;
            END;

            /* START NHO18102021 CR for Company Entity Code*/
            /*
            IF  v_owner_category    IN(  'I' , 'S' )
            THEN
                v_icps_mcib_file.entity_type    :=  'I';
            ELSE
                v_icps_mcib_file.entity_type    :=  'C';
            END IF;
            */

            IF  v_client_record.corporate_id IS NOT NULL
            THEN
                IF regexp_like(v_client_record.LEGAL_ID,'^[0-9]{1}')
                THEN
                    v_icps_mcib_file.entity_code    :=  substr(v_client_record.LEGAL_ID,1,LENGTH(v_client_record.LEGAL_ID)) ;
                    v_icps_mcib_file.entity_type    :=  '' ;
                ELSE
                    v_icps_mcib_file.entity_code    :=  substr(v_client_record.LEGAL_ID,2,LENGTH(v_client_record.LEGAL_ID)) ;
                    v_icps_mcib_file.entity_type    :=  substr(v_client_record.LEGAL_ID,1,1) ;
                END IF;
            ELSE
                v_icps_mcib_file.entity_code    :=  v_client_record.LEGAL_ID ;
                v_icps_mcib_file.entity_type    :=  'I' ;
            END IF;
            /* END NHO18102021 CR for Company Entity Code*/

            v_icps_mcib_file.entity_name            :=  v_client_record.family_name ;
            v_icps_mcib_file.entity_other_name      :=  v_client_record.first_name ;

            IF v_client_record.corporate_id IS NULL   --BJH20052019
            THEN
                v_icps_mcib_file.dob                    :=  to_char(v_client_record.birth_date,'ddmmyyyy')  ;
                v_icps_mcib_file.sex                    :=  v_client_record.gender ;
            ELSE
                v_icps_mcib_file.dob                    :=  NULL ;
                v_icps_mcib_file.sex                    :=  NULL ;
            END IF ;



            IF  NVL( v_client_record.nationality_code , '480' ) <> '480'
            THEN
                v_icps_mcib_file.resident_flag  :=  'N' ;

                Return_Status   :=  PCRD_GET_PARAM_GENERAL_ROWS.GET_COUNTRY (   v_client_record.nationality_code,
                                                                                v_country_record);
                IF (Return_status <>  declaration_cst.OK)
                THEN
                    v_env_info_trace.user_message   :=  'ERROR RETURNED BY PCRD_GET_PARAM_GENERAL_ROWS.GET_COUNTRY'
                                                    ||  ', Country Code : ' || v_client_record.nationality_code;
                    PCRD_GENERAL_TOOLS.PUT_TRACES (v_env_info_trace, 500);
                    ROLLBACK;
                    RETURN (Return_Status);
                END IF;
                v_icps_mcib_file.country_code   :=  v_country_record.visa_country_code ;
                v_icps_mcib_file.passport_no    :=  v_client_record.legal_id ;

            ELSE
                v_icps_mcib_file.country_code   :=  'MU' ;
                v_icps_mcib_file.resident_flag  :=  'R' ;
                v_icps_mcib_file.passport_no    :=  NULL;

            END IF ;

            /* RETURN_STATUS   :=  PCRD_GET_ADDRESS.GET_CLIENT_ADDRESS   (    SYSDATE,
                                                                           v_client_record,
                                                                           v_addresses_table_record,
                                                                           v_error_code,
                                                                           v_client_record.preferred_mailing_address,
                                                                           'preferred_mailing_address');
            IF  (Return_status <> declaration_cst.OK)
            THEN
                    v_env_info_trace.user_message   :=  'ERROR RETURNED BY PCRD_GET_ADDRESS.GET_CLIENT_ADDRESS, '
                                                    ||  ' Client Code '    || v_client_record.client_code
                                                    ||  ' Address Type '   || 'preferred_mailing_address'
                                                    ||V_ERROR_CODE;
                    PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,600);
                    RETURN (Return_Status);
            END IF; */

            v_icps_mcib_file.address5                   :=  NULL ;

           /* BEGIN
                SELECT  city_name
                INTO    v_icps_mcib_file.address5
                FROM    CITY
                WHERE   v_addresses_table_record.city_code = city_code
                        AND country_code    =   v_addresses_table_record.country_code  ;

                EXCEPTION WHEN NO_DATA_FOUND
                THEN
                v_icps_mcib_file.address5                   :=  NULL ;

            RETURN Return_Status;
            WHEN OTHERS
            THEN
                v_env_info_trace.user_message   :=  'ERROR WHILE SELECT FROM CITY_CODE: '|| v_addresses_table_record.city_code ;
                PCRD_GENERAL_TOOLS.PUT_TRACES ( v_env_info_trace , 300 );
                RETURN  declaration_cst.NOK ;
            END; */

            v_icps_mcib_file.address1                   :=  v_client_record.pr_line_1;
            v_icps_mcib_file.address2                   :=  v_client_record.pr_line_2;
            v_icps_mcib_file.address3                   :=  v_client_record.pr_line_3;
            v_icps_mcib_file.address4                   :=  v_client_record.pr_line_4;
            v_icps_mcib_file.credit_type                := 'CRC'    ;
            /*v_icps_mcib_file.date_approved              :=  v_card_record.agreement_date    ;*/ /*VARAMG 130411 - The agreement date specified in shadow account*/
            --v_icps_mcib_file.date_approved              :=  v_shadow_account_record.agreement_date    ;
            v_icps_mcib_file.date_approved              :=  TO_CHAR(v_shadow_account_record.agreement_date, 'ddmmyyyy');
            v_icps_mcib_file.parent_co_no               :=  NULL;
            v_icps_mcib_file.parent_co_name             :=  NULL;
            --v_icps_mcib_file.sector_loan_class          :=  'FBS'   ;
            v_icps_mcib_file.sector_loan_class          :=  TRIM(v_client_record.tax_number ) ; --BJH30052019 To manage the sector loan code for CF
            --v_icps_mcib_file.curr                       :=  v_shadow_account_record.currency_code   ;
            v_icps_mcib_file.unique_ref_id              := NULL; --BJH25022019

            SELECT  currency_code_alpha
            INTO    v_icps_mcib_file.curr
            FROM    currency_table
            WHERE   currency_code = v_shadow_account_record.currency_code;

            RETURN_STATUS := PCRD_ICPS_GEN_MCBI_FILE.GET_BASIC_CARD_FROM_ACCOUNT  ( v_shadow_account_record.SHADOW_ACCOUNT_NBR, --BJH17062019
                                                                                    GLOBAL_VARS_1.ACCT_SHADOW_ACCOUNT,
                                                                                    v_card_record);
            IF RETURN_STATUS = DECLARATION_CST.ERROR
            THEN
                V_ENV_INFO_TRACE.USER_MESSAGE  := 'ERROR RETURNED BY PCRD_GET_ACCOUNT.GET_BASIC_CARD_FROM_ACCOUNT'
                                               || ', SHADOW ACCT NBR : ' || v_shadow_account_record.SHADOW_ACCOUNT_NBR;
                PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                ROLLBACK;
                RETURN(RETURN_STATUS);
            END IF;

            v_icps_mcib_file.ref_no                     :=  NVL(TRIM(v_card_record.pwrcd_internal_reference),v_shadow_account_record.shadow_account_nbr) ; --BJH12062019

            /*MH - ACKNOWLEDGEMENT FILE - START */
            BEGIN

                SELECT  unique_Ref_id
                INTO    v_ack_mapping
                FROM    ack_mapping_table
                WHERE   ack_mapping_table.ENTITY_CODE = v_client_record.legal_id
                AND     v_shadow_account_record.SHADOW_ACCOUNT_NBR = ack_mapping_table.ref_nO
                AND     ROWNUM = 1;

                v_icps_mcib_file.unique_ref_id              := v_ack_mapping;

                EXCEPTION WHEN NO_DATA_FOUND
                THEN
                v_ack_mapping                   :=  NULL ;

                WHEN OTHERS
                THEN
                    v_env_info_trace.user_message   :=  'ERROR SELECT unique_Ref_id INTO v_ack_mapping FROM ack_mapping_table '|| v_ack_mapping ;
                    PCRD_GENERAL_TOOLS.PUT_TRACES ( v_env_info_trace , 300 );
                    RETURN  declaration_cst.NOK ;
            END;


            /*MH - ACKNOWLEDGEMENT FILE - END */
            /*MH - ACKNOWLEDGEMENT FILE - START */
            BEGIN

                SELECT  unique_Ref_id
                INTO    v_ack_mapping
                FROM    ack_mapping_table
                WHERE   ack_mapping_table.ENTITY_CODE = v_client_record.legal_id
                AND     v_icps_mcib_file.ref_no = ack_mapping_table.ref_nO
                AND     ROWNUM = 1;

                v_icps_mcib_file.unique_ref_id              := v_ack_mapping;

                EXCEPTION WHEN NO_DATA_FOUND
                THEN
                v_ack_mapping                   :=  NULL ;

                WHEN OTHERS
                THEN
                    v_env_info_trace.user_message   :=  'ERROR SELECT unique_Ref_id INTO v_ack_mapping FROM ack_mapping_table '|| v_ack_mapping ;
                    PCRD_GENERAL_TOOLS.PUT_TRACES ( v_env_info_trace , 300 );
                    RETURN  declaration_cst.NOK ;
            END;
            /*MH - ACKNOWLEDGEMENT FILE - END */

            v_icps_mcib_file.amount_org                 :=  v_shadow_account_record.credit_limit    ;
--start Add suppl account to amount_out--MAK17122019--add supplementary balance for corporate accounts
BEGIN
SELECT sum(aa.somme)  into v_sum_supl_acc
  FROM (SELECT   NVL (current_balance_purchase, 0.0)
               + NVL (current_balance_cash, 0.0)
               + NVL (current_balance_transfer, 0.0)
               + NVL (current_balance_ecom, 0.0)
               + NVL (current_balance_cheque, 0.0)
               + NVL (current_balance_interest, 0.0)
               + NVL (current_balance_installment, 0.0)
               + NVL (current_balance_fees, 0.0)
               + NVL (current_balance_tax, 0.0)
               - NVL (current_balance_refund, 0.0)
               - NVL (current_balance_deposit, 0.0) as somme
          FROM shadow_account
         WHERE primary_shadow_account_nbr = v_shadow_account_record.shadow_account_nbr) aa;
EXCEPTION WHEN OTHERS
THEN
                V_ENV_INFO_TRACE.USER_MESSAGE  := 'ERROR RETURNED ADD SUPPL ACCOUNT TO AMOUNT_OUT '
                                               || ', SHADOW ACCT NBR : ' || v_shadow_account_record.SHADOW_ACCOUNT_NBR;
                PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                ROLLBACK;
                RETURN declaration_cst.ERROR;
END ;

            v_icps_mcib_file.amount_out                 :=
                              NVL( v_shadow_account_record.closing_balance_purchase        , 0.0)
                            + NVL( v_shadow_account_record.closing_balance_cash            , 0.0)
                            + NVL( v_shadow_account_record.closing_balance_transfer        , 0.0)
                            + NVL( v_shadow_account_record.closing_balance_ecom            , 0.0)
                            + NVL( v_shadow_account_record.closing_balance_cheque          , 0.0)
                            + NVL( v_shadow_account_record.closing_balance_interest        , 0.0)
                            + NVL( v_shadow_account_record.closing_balance_installment     , 0.0)
                            + NVL( v_shadow_account_record.closing_balance_fees            , 0.0)
                            + NVL( v_shadow_account_record.closing_balance_tax             , 0.0)
                            + NVL( v_shadow_account_record.current_balance_purchase        , 0.0)
                            + NVL( v_shadow_account_record.current_balance_cash            , 0.0)
                            + NVL( v_shadow_account_record.current_balance_transfer        , 0.0)
                            + NVL( v_shadow_account_record.current_balance_ecom            , 0.0)
                            + NVL( v_shadow_account_record.current_balance_cheque          , 0.0)
                            + NVL( v_shadow_account_record.current_balance_interest        , 0.0)
                            + NVL( v_shadow_account_record.current_balance_installment     , 0.0)
                            + NVL( v_shadow_account_record.current_balance_fees            , 0.0)
                            + NVL( v_shadow_account_record.current_balance_tax             , 0.0)
                            - NVL( v_shadow_account_record.closing_balance_refund          , 0.0)
                            - NVL( v_shadow_account_record.closing_balance_deposit         , 0.0)
                            - NVL( v_shadow_account_record.current_balance_refund          , 0.0)
                            - NVL( v_shadow_account_record.current_balance_deposit         , 0.0) ;


            v_icps_mcib_file.amount_out := v_icps_mcib_file.amount_out + nvl(v_sum_supl_acc,0.0); ---MAK17122019--add supplementary balance for corporate accounts

            IF v_icps_mcib_file.amount_out < 0
            THEN
                v_icps_mcib_file.amount_out     := 0.00 ;
            END IF;

            v_icps_mcib_file.amount_dis                 :=  NULL    ;

            --
           /* IF  v_shadow_account_record.date_last_statement IS NOT NULL
            THEN
                IF  v_shadow_account_record.date_last_statement > SYSDATE
                THEN
                    v_icps_mcib_file.date_update                := TO_CHAR(SYSDATE-1, 'ddmmyyyy');
                ELSE
                    v_icps_mcib_file.date_update                :=  TO_CHAR(v_shadow_account_record.date_last_statement, 'ddmmyyyy') ;
                END IF;
            ELSE
                v_icps_mcib_file.date_update            :=  TO_CHAR(SYSDATE-1, 'ddmmyyyy');


            END IF ;*/
            v_icps_mcib_file.date_update            := TO_CHAR (p_business_date, 'ddmmyyyy');
            v_icps_mcib_file.amount_inst                :=  0.00 ; --PA19022020
--            v_icps_mcib_file.amount_inst                :=  NVL(v_cr_term_rec.minimum_due,0) ; --BJH25022019
            v_icps_mcib_file.date_first_inst            :=  NULL;
            v_icps_mcib_file.periodicity                :=  NULL;
            v_icps_mcib_file.date_last_inst             :=  NULL;

            --BJH30052019
            IF  v_client_record.corporate_id IS NOT NULL
            THEN
                --IF v_shadow_account_record.administrative_status   = '7'
                IF v_shadow_account_record.administrative_status in ('7','6','5')--to cater for deceased and cancelled accounts--PA19022020
                THEN
                    v_icps_mcib_file.date_exp         :=  TO_CHAR(v_shadow_account_record.administrative_status_date , 'DDMMYYYY');

                ELSE
                    RETURN_STATUS := PCRD_ICPS_GEN_MCBI_FILE.GET_MAX_EXPIRY_DATE_CARD  ( v_shadow_account_record.shadow_account_nbr,
                                                                                         GLOBAL_VARS_1.ACCT_SHADOW_ACCOUNT,
                                                                                         v_corporate_card_record);
                    IF RETURN_STATUS = DECLARATION_CST.ERROR
                    THEN
                        V_ENV_INFO_TRACE.USER_MESSAGE  := 'ERROR RETURNED BY PCRD_ICPS_GEN_MCBI_FILE.GET_MAX_EXPIRY_DATE_CARD'
                                                       || ', SHADOW ACCT NBR : ' || v_shadow_account_record.shadow_account_nbr;
                        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                        ROLLBACK;
                        RETURN(RETURN_STATUS);
                    END IF;

                    v_icps_mcib_file.date_exp         :=  TO_CHAR(v_corporate_card_record.expiry_date , 'DDMMYYYY');

                END IF;
            ELSE
                --IF v_shadow_account_record.administrative_status   = '7'
                IF v_shadow_account_record.administrative_status in ('7','6','5')--to cater for deceased and cancelled accounts--PA19022020
                THEN
                    v_icps_mcib_file.date_exp         :=  TO_CHAR(v_shadow_account_record.administrative_status_date , 'DDMMYYYY');

                ELSIF TRUNC(v_card_record.expiry_date) > TRUNC(SYSDATE) AND v_card_record.status_code = 'C'
                THEN
                        --v_icps_mcib_file.date_exp     :=  TO_CHAR(v_card_record.status_date , 'DDMMYYYY');
                        v_icps_mcib_file.date_exp     :=  TO_CHAR(p_business_date , 'DDMMYYYY'); --NHO18102021 MCIB CR to use system date instead of status date for cancelled cards

                ELSIF TRUNC(v_card_record.expiry_date) < TRUNC(SYSDATE) AND v_card_record.basic_card_number IS NOT NULL
                THEN
                     RETURN_STATUS :=  PCRD_GET_DATA_CARD_ROWS.GET_CARD (v_card_record.basic_card_number,
                                                                         v_basic_card_record );
                     IF RETURN_STATUS <> DECLARATION_CST.OK
                     THEN
                        V_ENV_INFO_TRACE.USER_MESSAGE  := 'ERROR RETURNED BY PCRD_GET_DATA_CARD_ROWS.GET_CARD'
                                                       || ', SHADOW ACCT NBR : ' || v_card_record.basic_card_number;
                        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                        ROLLBACK;
                        RETURN(RETURN_STATUS);
                     END IF;

                     --v_icps_mcib_file.date_exp         :=  TO_CHAR(v_basic_card_record.expiry_date , 'DDMMYYYY');
                     v_icps_mcib_file.date_exp         :=  TO_CHAR(p_business_date , 'DDMMYYYY');--NHO18102021 to use system date instead of status date for cancelled cards

                /*START NHO15112021 - MCIB CR - FACILITY EXPIRED*/
                ELSIF TRUNC(v_card_record.expiry_date) < TRUNC(SYSDATE)
                THEN
                     v_icps_mcib_file.date_exp         :=  TO_CHAR(p_business_date , 'DDMMYYYY');
                /*END NHO15112021 - MCIB CR - FACILITY EXPIRED*/

                ELSE
                     v_icps_mcib_file.date_exp         :=  TO_CHAR(v_card_record.expiry_date , 'DDMMYYYY');
                END IF;
            END IF;

            v_icps_mcib_file.no_inst                    :=  NULL;
            IF  v_shadow_account_record.unpaid_status   <> '0'
            THEN
                    --START MAK_20191205
                    BEGIN
                        SELECT FIRST_UNPAID_DATE
                        INTO V_FIRST_UNPAID_DATE
                        FROM SHADOW_ACCOUNT_UNPAID_STATUS
                        WHERE SHADOW_ACCOUNT_NBR = V_SHADOW_ACCOUNT_RECORD.SHADOW_ACCOUNT_NBR
                        AND ROWNUM = 1 ;
                        EXCEPTION WHEN NO_DATA_FOUND
                        THEN
                        NULL;
                        WHEN OTHERS
                        THEN
                            V_ENV_INFO_TRACE.USER_MESSAGE   :=  'OTHERS ERROR : '           ||  SUBSTR(SQLERRM,1,100);
                            PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                            ROLLBACK;
                            RETURN DECLARATION_CST.ERROR;
                    END;

                    IF V_FIRST_UNPAID_DATE IS NULL
                    THEN
                        BEGIN
                        INSERT INTO SHADOW_ACCOUNT_UNPAID_STATUS VALUES (V_SHADOW_ACCOUNT_RECORD.SHADOW_ACCOUNT_NBR ,NVL(V_SHADOW_ACCOUNT_RECORD.FIRST_UNPAID_DATE,V_SHADOW_ACCOUNT_RECORD.UNPAID_STATUS_DATE),V_SHADOW_ACCOUNT_RECORD.CLOSING_BALANCE,USER, SYSDATE,NULL,NULL );
                        EXCEPTION WHEN OTHERS THEN
                            V_ENV_INFO_TRACE.USER_MESSAGE   :=  'OTHERS ERROR : '           ||  SUBSTR(SQLERRM,1,100);
                            PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                            ROLLBACK;
                            RETURN DECLARATION_CST.ERROR;
                        END ;

                    V_FIRST_UNPAID_DATE := NVL(V_SHADOW_ACCOUNT_RECORD.FIRST_UNPAID_DATE,V_SHADOW_ACCOUNT_RECORD.UNPAID_STATUS_DATE);
                    END IF;
                    --END MAK_20191205
                IF v_shadow_account_record.unpaid_status_date > p_business_date
                THEN
                    v_icps_mcib_file.date_default           :=  TO_CHAR(p_business_date -1, 'ddmmyyyy');
                ELSE
                    --v_icps_mcib_file.date_default           :=  TO_CHAR(v_shadow_account_record.first_unpaid_date, 'ddmmyyyy'); --BJH14062019
                    v_icps_mcib_file.date_default           :=  NVL(TO_CHAR(v_first_unpaid_date,'ddmmyyyy'),TO_CHAR(v_shadow_account_record.first_unpaid_date, 'ddmmyyyy'));
                END IF;

                --BJH14032019
                BEGIN
                    SELECT closing_balance
                    INTO   v_icps_mcib_file.bal_default
                    --FROM CR_TERM
                    FROM v_CR_TERM_view
                    WHERE shadow_account_nbr =  v_shadow_account_record.shadow_Account_nbr
--                    AND TO_CHAR(term_overdue_date, 'ddmmyyyy') = TO_CHAR(v_shadow_account_record.first_unpaid_date, 'ddmmyyyy')
                    AND TO_CHAR(term_overdue_date, 'ddmmyyyy') = TO_CHAR(v_first_unpaid_date, 'ddmmyyyy')------PA06122019--to overcome issue of balance_def =0 when date_default=DATE
                    --AND term_overdue_date = TO_date(v_first_unpaid_date, 'ddmmyyyy')------PA06122019--to overcome issue of balance_def =0 when date_default=DATE

                    AND ROWNUM = 1 ;

                /*START NHO24112021 - BAL_DEFAULT CR*/
                EXCEPTION WHEN NO_DATA_FOUND
                THEN
                        SELECT closing_balance
                        INTO   v_icps_mcib_file.bal_default
                        FROM   SHADOW_ACCOUNT_UNPAID_STATUS
                        WHERE shadow_account_nbr =  v_shadow_account_record.shadow_Account_nbr
                        AND TO_CHAR(first_unpaid_date, 'ddmmyyyy') = TO_CHAR(v_first_unpaid_date, 'ddmmyyyy')
                        AND ROWNUM = 1
                        ORDER BY first_unpaid_date desc;
                /*end NHO24112021 - BAL_DEFAULT CR*/

                WHEN OTHERS
                THEN
                    v_icps_mcib_file.bal_default            :=  0.0 ;
                END;
                --BJH14062019
                v_icps_mcib_file.amount_arrs            :=  NVL(v_shadow_account_record.terms_unpaid_amount,NULL); --BJH17062019
--                v_icps_mcib_file.type_class             :=  ABS(TRUNC(p_business_date) - TRUNC(v_shadow_account_record.first_unpaid_date)); --v_cr_term_rec.terms_unpaid_nbr; --BJH25022019
                --v_icps_mcib_file.type_class             :=  ABS(TRUNC(to_date(p_business_date,'ddmmyyyy')) - TRUNC(TO_date(v_first_unpaid_date,'ddmmyyyy'))); --PA06122019--no.of days of arrears from first unpaid date

                BEGIN
                 --v_icps_mcib_file.type_class             :=  ABS(TRUNC(to_date(p_business_date,'ddmmyyyy')) - TRUNC(TO_date(NVL(v_first_unpaid_date,v_shadow_account_record.first_unpaid_date),'ddmmyyyy'))); --AL20191212 Batch Crash
                        v_icps_mcib_file.type_class             :=  ABS(TRUNC(p_business_date) - TRUNC(v_first_unpaid_date)); --PA06122019--no.of days of arrears from first unpaid date
                 ---YM18082020-  TYPE CLASS CHANGE REQUEST
                        SELECT NVL (MAX(TRUNC(p_business_date) - TRUNC(term_overdue_date)),0) into v_no_days
                        FROM    CR_TERM
                        WHERE   shadow_account_nbr   =    v_shadow_account_record.shadow_Account_nbr;

                        IF v_no_days > 0
                        THEN
                        v_icps_mcib_file.type_class := v_no_days;
                        ELSE
                       --v_icps_mcib_file.type_class := 0 ;
                       v_icps_mcib_file.type_class := 1 ; --nawkho_08042022_ticket 159084
                        END IF;
                  ---YM18082020-  TYPE CLASS CHANGE REQUEST

                EXCEPTION
                WHEN OTHERS
                THEN
                    --v_icps_mcib_file.type_class := 0 ;
                    v_icps_mcib_file.type_class := 1; --nawkho_08042022_ticket 159084
                END ;

            ELSE

--Start MAK_20191205
                BEGIN
                DELETE FROM SHADOW_ACCOUNT_UNPAID_STATUS WHERE SHADOW_ACCOUNT_NBR = V_SHADOW_ACCOUNT_RECORD.SHADOW_ACCOUNT_NBR;
                   EXCEPTION WHEN OTHERS THEN
                    V_ENV_INFO_TRACE.USER_MESSAGE   :=  'OTHERS ERROR : '           ||  SUBSTR(SQLERRM,1,100);
                    PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                    ROLLBACK;
                    RETURN DECLARATION_CST.ERROR;
                END;
--End MAK_20191205
                /*IF  TRUNC(v_shadow_account_record.unpaid_status_date )      <>  TRUNC(v_shadow_account_record.date_create)
                    AND TRUNC(v_shadow_account_record.unpaid_status_date )  =   p_business_date
                THEN
                    v_icps_mcib_file.date_regularised   :=  TO_CHAR(v_shadow_account_record.unpaid_status_date, 'ddmmyyyy') ;
                END IF ;*/
                --BJH14062019
                RETURN_STATUS :=  PCRD_ICPS_GEN_MCBI_FILE.GET_LAST_TERM (v_shadow_account_record.shadow_Account_nbr,
                                                                         v_cr_term_rec );
                 IF RETURN_STATUS <> DECLARATION_CST.OK
                 THEN
                    V_ENV_INFO_TRACE.USER_MESSAGE  := 'ERROR RETURNED BY PCRD_ICPS_GEN_MCBI_FILE.GET_LAST_TERM'
                                                   || ', SHADOW ACCT NBR : ' || v_shadow_account_record.shadow_Account_nbr;
                    PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                    ROLLBACK;
                    RETURN(RETURN_STATUS);
                 END IF;

IF v_cr_term_rec.unpaid_status <> '0' and v_shadow_account_record.unpaid_status = 0

   THEN

    IF
        TO_CHAR(v_shadow_account_record.unpaid_status_date, 'ddmmyyyy') = to_char(p_business_date, 'ddmmyyyy')
        THEN
         v_icps_mcib_file.date_regularised   :=  TO_CHAR(v_shadow_account_record.unpaid_status_date, 'ddmmyyyy') ;
        ELSE
         v_icps_mcib_file.date_regularised   := NULL;
        END IF;
END IF;

--start MAK
    BEGIN
    SELECT next_processing_date
      INTO v_next_processing_date
      FROM CYCLE_CUTOFF_LIST
     WHERE cycle_code = v_shadow_account_record.cycle_cutoff_code;
     EXCEPTION WHEN OTHERS
     THEN
         v_env_info_trace.user_message   :=  'OTHERS ERROR SELECT FROM CYCLE_CUTOFF_LIST: '           ||  SUBSTR(SQLERRM,1,100);
        PCRD_GENERAL_TOOLS.PUT_TRACES    (   v_env_info_trace , 2000 );
        RETURN declaration_cst.ERROR;
    END;

    V_ENV_INFO_TRACE.USER_MESSAGE   :=
    ' V_SHADOW_ACCOUNT_RECORD.SHADOW_ACCOUNT_NBR = [' || V_SHADOW_ACCOUNT_RECORD.SHADOW_ACCOUNT_NBR ||
    '] - V_NEXT_PROCESSING_DATE : [' ||  V_NEXT_PROCESSING_DATE ||
    '] - V_CR_TERM_REC.UNPAID_STATUS = '|| V_CR_TERM_REC.UNPAID_STATUS ||
    '] - V_SHADOW_ACCOUNT_RECORD.F_UNPAID_STATUS = [' || V_SHADOW_ACCOUNT_RECORD.F_UNPAID_STATUS ||
    '] - V_SHADOW_ACCOUNT_RECORD.UNPAID_STATUS [' || V_SHADOW_ACCOUNT_RECORD.UNPAID_STATUS ||
    '] - V_SHADOW_ACCOUNT_RECORD.UNPAID_STATUS_DATE = [' || V_SHADOW_ACCOUNT_RECORD.UNPAID_STATUS_DATE ||
    '] - V_SHADOW_ACCOUNT_RECORD.DATE_LAST_STATEMENT = [' || V_SHADOW_ACCOUNT_RECORD.DATE_LAST_STATEMENT ||']';
    --PCRD_GENERAL_TOOLS.PUT_TRACES    (   V_ENV_INFO_TRACE , 2010 );

 -- START CR DATE REGULARIZED 07 JULY 2021 OPP1490-Amendment to MCIB Regularized Date
/*    IF v_cr_term_rec.unpaid_status ='0'
        and v_shadow_account_record.unpaid_status = 0
        and v_shadow_account_record.unpaid_status_date > v_shadow_account_record.date_last_statement
        and v_shadow_account_record.f_unpaid_status_date > v_shadow_account_record.date_last_statement
        and v_shadow_account_record.unpaid_status_date < v_next_processing_date
        and v_shadow_account_record.f_unpaid_status <> 0
    THEN*/

    --(2) Every 15 of the month, date_regularised is missing for accounts whose arrears have been fully paid



    IF substr((to_char(p_business_date,'DDMMYYYY')),1,2) <> '15'
    THEN
    -- start nawkho_26082021
    /*IF v_shadow_account_record.shadow_account_nbr in ('C310012643','C310003824')
    THEN
     v_icps_mcib_file.date_regularised   := '03092021' ;
    END IF;*/
    -- end nawkho_26082021
   IF v_cr_term_rec.unpaid_status ='0'
        and v_shadow_account_record.unpaid_status = 0
        and v_shadow_account_record.unpaid_status_date > v_shadow_account_record.date_last_statement
        and v_shadow_account_record.f_unpaid_status_date > v_shadow_account_record.date_last_statement
        and v_shadow_account_record.unpaid_status_date < v_next_processing_date
        and v_shadow_account_record.f_unpaid_status <> 0
    THEN

            IF TO_CHAR(v_shadow_account_record.unpaid_status_date, 'ddmmyyyy') = to_char(p_business_date, 'ddmmyyyy')
            THEN
             v_icps_mcib_file.date_regularised   :=  TO_CHAR(v_shadow_account_record.unpaid_status_date, 'ddmmyyyy') ;
            ELSE
             v_icps_mcib_file.date_regularised   := NULL;
            END IF;

    END IF;

    ELSE
     IF v_cr_term_rec.unpaid_status ='0'
        and v_shadow_account_record.unpaid_status = 0
        and v_shadow_account_record.unpaid_status_date = v_shadow_account_record.date_last_statement
--        and v_shadow_account_record.f_unpaid_status_date > v_shadow_account_record.date_last_statement
        and v_shadow_account_record.unpaid_status_date < v_next_processing_date
        and v_shadow_account_record.f_unpaid_status <> 0
    THEN

            IF TO_CHAR(v_shadow_account_record.unpaid_status_date, 'ddmmyyyy') = to_char(p_business_date, 'ddmmyyyy')
            THEN
             v_icps_mcib_file.date_regularised   :=  TO_CHAR(v_shadow_account_record.unpaid_status_date, 'ddmmyyyy') ;
            ELSE
             v_icps_mcib_file.date_regularised   := NULL;
            END IF;

    END IF;
  END IF;
        --(1) For newly created account, date_regularised should not be present as the account is not in arrears.
        --IF TO_CHAR (v_icps_mcib_file.date_approved, 'DDMMYYYY') = TO_CHAR(p_business_date, 'ddmmyyyy')
        IF v_icps_mcib_file.date_approved = TO_CHAR(p_business_date, 'ddmmyyyy')

        THEN
            v_icps_mcib_file.date_regularised   := NULL ;
        END IF ;


    -- END CR DATE REGULARIZED 07 JULY 2021 OPP1490-Amendment to MCIB Regularized Date

--end mak
 /*

                IF v_cr_term_rec.unpaid_status <> '0'
                THEN
                    v_icps_mcib_file.date_regularised   :=  TO_CHAR(v_shadow_account_record.unpaid_status_date, 'ddmmyyyy') ;
                END IF;

     */

            END IF ;

           -- v_icps_mcib_file.first_coll                 :=  'CARD'; --BJH17062019
            v_icps_mcib_file.first_coll                 :=  'NA'; --YM16022023 - NRF_CFSL_2023_1- CIM Finance - CR - MCIB - Changes to Tag FIRST_COLL--
            v_icps_mcib_file.second_coll                :=  NULL;
            v_icps_mcib_file.third_coll                 :=  NULL;
            v_icps_mcib_file.fourth_coll                :=  NULL;
            v_icps_mcib_file.fifth_coll                 :=  NULL;
            v_icps_mcib_file.remarks                    :=  NULL;

            IF  v_shadow_account_record.credit_request_file_number     IS NOT NULL
            THEN
                v_record_status                         :=  'A';
            ELSE
                v_record_status                         :=  'N';
                UPDATE  shadow_account
                SET     credit_request_file_number      =   'U'|| v_shadow_account_record.shadow_account_nbr  || '_' ||TO_CHAR(v_shadow_account_record.date_create , 'DDMMYYYY')
                WHERE   shadow_account_nbr              =   v_shadow_account_record.shadow_account_nbr;
            END IF;
            v_icps_mcib_file.record_status              :=  NVL(v_record_status , 'A') ;

---YM07082020 - Ticket 116195-- to include change for write-off attorney account
            IF v_shadow_account_record.administrative_status IN ('5', '6','7','8','9')
            and v_shadow_account_record.status_reason_code =  'WO'
            THEN
            v_icps_mcib_file.action_taken               :=  'TRANSFER TO ATTORNEY';

                IF v_shadow_account_record.administrative_status_date IS NULL --RT26102020
                THEN
                    v_icps_mcib_file.action_date := NULL;
                ELSE
                    v_icps_mcib_file.action_date  :=  TO_CHAR (v_shadow_account_record.administrative_status_date,'ddmmyyyy');

                END IF;
            ELSE
            v_icps_mcib_file.action_taken               :=  NULL    ;
            v_icps_mcib_file.action_date                :=  NULL    ;
            END IF;
---YM07082020 - Ticket 116195-- to include change for write-off attorney account

            INSERT  INTO    ICPS_MCIB_FILE VALUES v_icps_mcib_file ;
        END IF;

        << NEXT_RECORD >>
         NULL;
    END LOOP;

    RETURN declaration_cst.OK;

EXCEPTION
WHEN OTHERS THEN
    v_env_info_trace.user_message   :=  'OTHERS ERROR : '           ||  SUBSTR(SQLERRM,1,100);
    PCRD_GENERAL_TOOLS.PUT_TRACES    (   v_env_info_trace , 2000 );
    ROLLBACK;
    RETURN declaration_cst.ERROR;
END FUNC_MCIB_OUTPUT_FILE;
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--BJH30052019
FUNCTION    GET_MAX_EXPIRY_DATE_CARD    (   P_PRIMARY_ACCOUNT_NBR               IN              SHADOW_ACCOUNT.PRIMARY_SHADOW_ACCOUNT_NBR%TYPE,
                                            P_ACCOUNT_TYPE                      IN              ACCOUNTS_LINK.ACCOUNT_TYPE%TYPE DEFAULT NULL,
                                            P_CARD_RECORD                       OUT NOCOPY      CARD%ROWTYPE)
                                            RETURN PLS_INTEGER IS

RETURN_STATUS                       PLS_INTEGER;

BEGIN
    BEGIN
        SELECT      *
        INTO        P_CARD_RECORD
        FROM        (       SELECT      CARD.*
                            FROM        CARD,
                                        ACCOUNTS_LINK
                            WHERE       ACCOUNTS_LINK.ENTITY_CODE                       =           GLOBAL_VARS_1.EC_CARDHOLDER
                                    AND ACCOUNTS_LINK.ENTITY_ID                         =           CARD.CARD_NUMBER
                                    AND ACCOUNTS_LINK.ACCOUNT_NUMBER                    IN          (SELECT shadow_account_nbr FROM SHADOW_ACCOUNT
                                                                                                      where primary_shadow_account_nbr = P_PRIMARY_ACCOUNT_NBR  )
                                    AND NVL(P_ACCOUNT_TYPE, ACCOUNTS_LINK.ACCOUNT_TYPE) =           ACCOUNTS_LINK.ACCOUNT_TYPE
                                    ORDER BY EXPIRY_DATE DESC
                    )
        WHERE ROWNUM = 1;
        RETURN(DECLARATION_CST.OK);

        EXCEPTION WHEN NO_DATA_FOUND
        THEN
                RETURN(DECLARATION_CST.NOK);
        WHEN OTHERS
        THEN
            DECLARE
                V_ENV_INFO_TRACE            GLOBAL_VARS.ENV_INFO_TRACE_TYPE;
                BEGIN
                        V_ENV_INFO_TRACE.USER_NAME      :=  GLOBAL_VARS.USER_NAME;
                        V_ENV_INFO_TRACE.MODULE_CODE    :=  GLOBAL_VARS.ML_CREDIT_REVOLVING;
                        V_ENV_INFO_TRACE.PACKAGE_NAME   :=  $$PLSQL_UNIT;
                        V_ENV_INFO_TRACE.FUNCTION_NAME  :=  'GET_BASIC_CARD_FROM_ACCOUNT';
                        V_ENV_INFO_TRACE.LANG           :=  GLOBAL_VARS.LANG;
                        V_ENV_INFO_TRACE.USER_MESSAGE   :=  NULL;

                        V_ENV_INFO_TRACE.PARAM1         := 'CARD, ACCOUNTS_LINK';
                        V_ENV_INFO_TRACE.PARAM2         :=' ACCOUNT_NUMBER :='||P_PRIMARY_ACCOUNT_NBR;
                        V_ENV_INFO_TRACE.ERROR_CODE     := 'PWC-00021';

                        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                        RETURN (DECLARATION_CST.ERROR);
                END;
    END;
    EXCEPTION WHEN OTHERS
    THEN
            DECLARE
                V_ENV_INFO_TRACE            GLOBAL_VARS.ENV_INFO_TRACE_TYPE;
                BEGIN
                        V_ENV_INFO_TRACE.USER_NAME      :=  GLOBAL_VARS.USER_NAME;
                        V_ENV_INFO_TRACE.MODULE_CODE    :=  GLOBAL_VARS.ML_CREDIT_REVOLVING;
                        V_ENV_INFO_TRACE.PACKAGE_NAME   :=  $$PLSQL_UNIT;
                        V_ENV_INFO_TRACE.FUNCTION_NAME  :=  'GET_MAX_EXPIRY_DATE_CARD';
                        V_ENV_INFO_TRACE.LANG           :=  GLOBAL_VARS.LANG;
                        V_ENV_INFO_TRACE.USER_MESSAGE   :=  NULL;
                        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                        RETURN (DECLARATION_CST.ERROR);
                END;

END GET_MAX_EXPIRY_DATE_CARD;
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--BJH17062019
FUNCTION    GET_BASIC_CARD_FROM_ACCOUNT (   P_ACCOUNT_NUMBER                IN              ACCOUNTS_LINK.ACCOUNT_NUMBER%TYPE,
                                            P_ACCOUNT_TYPE                  IN              ACCOUNTS_LINK.ACCOUNT_TYPE%TYPE DEFAULT NULL,
                                            P_CARD_RECORD                   OUT NOCOPY      CARD%ROWTYPE)
                                            RETURN PLS_INTEGER IS

RETURN_STATUS                       PLS_INTEGER;

BEGIN
    BEGIN
        SELECT      *
        INTO        P_CARD_RECORD
        FROM        (       SELECT      CARD.*
                            FROM        CARD,
                                        ACCOUNTS_LINK
                            WHERE       ACCOUNTS_LINK.ENTITY_CODE                       =           GLOBAL_VARS_1.EC_CARDHOLDER
                                    AND ACCOUNTS_LINK.ENTITY_ID                         =           CARD.CARD_NUMBER
                                    AND ACCOUNTS_LINK.ACCOUNT_NUMBER                    =           P_ACCOUNT_NUMBER
                                    AND CARD.STATUS_CODE                                IN          ('N', 'M') --BJH17062019
                                    AND NVL(P_ACCOUNT_TYPE, ACCOUNTS_LINK.ACCOUNT_TYPE) =           ACCOUNTS_LINK.ACCOUNT_TYPE
                                    AND CARD.BASIC_CARD_NUMBER                          IS  NULL

                                    ORDER BY EXPIRY_DATE DESC
                    )
        WHERE ROWNUM = 1;
        RETURN(DECLARATION_CST.OK);

        EXCEPTION WHEN NO_DATA_FOUND
        THEN
               --
                BEGIN
                SELECT      *
                INTO        P_CARD_RECORD
                FROM        ( SELECT  CARD.*
                              FROM    CARD,
                                      ACCOUNTS_LINK
                              WHERE  ACCOUNTS_LINK.ENTITY_CODE                    =  GLOBAL_VARS_1.EC_CARDHOLDER
                              AND ACCOUNTS_LINK.ENTITY_ID                         =  CARD.CARD_NUMBER
                              AND ACCOUNTS_LINK.ACCOUNT_NUMBER                    =  P_ACCOUNT_NUMBER
                              AND NVL(P_ACCOUNT_TYPE, ACCOUNTS_LINK.ACCOUNT_TYPE) =  ACCOUNTS_LINK.ACCOUNT_TYPE
                              AND CARD.BASIC_CARD_NUMBER                          IS  NULL
                              ORDER BY EXPIRY_DATE DESC
                            )
                WHERE ROWNUM = 1;
                RETURN(DECLARATION_CST.OK);

                EXCEPTION WHEN NO_DATA_FOUND
                THEN
                        RETURN(DECLARATION_CST.NOK);
                WHEN OTHERS
                THEN
                    DECLARE
                        V_ENV_INFO_TRACE            GLOBAL_VARS.ENV_INFO_TRACE_TYPE;
                        BEGIN
                                V_ENV_INFO_TRACE.PACKAGE_NAME   :=  $$PLSQL_UNIT;
                                V_ENV_INFO_TRACE.FUNCTION_NAME  :=  'GET_BASIC_CARD_FROM_ACCOUNT';
                                V_ENV_INFO_TRACE.LANG           :=  GLOBAL_VARS.LANG;
                                V_ENV_INFO_TRACE.USER_MESSAGE   :=  NULL;
                                PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                                RETURN (DECLARATION_CST.ERROR);
                        END;
                END;
               --
        WHEN OTHERS
        THEN
            DECLARE
                V_ENV_INFO_TRACE            GLOBAL_VARS.ENV_INFO_TRACE_TYPE;
                BEGIN
                        V_ENV_INFO_TRACE.USER_NAME      :=  GLOBAL_VARS.USER_NAME;
                        V_ENV_INFO_TRACE.MODULE_CODE    :=  GLOBAL_VARS.ML_CREDIT_REVOLVING;
                        V_ENV_INFO_TRACE.PACKAGE_NAME   :=  $$PLSQL_UNIT;
                        V_ENV_INFO_TRACE.FUNCTION_NAME  :=  'GET_BASIC_CARD_FROM_ACCOUNT';
                        V_ENV_INFO_TRACE.LANG           :=  GLOBAL_VARS.LANG;
                        V_ENV_INFO_TRACE.USER_MESSAGE   :=  NULL;

                        V_ENV_INFO_TRACE.PARAM1         := 'CARD, ACCOUNTS_LINK';
                        V_ENV_INFO_TRACE.PARAM2         :=
' ACCOUNT_NUMBER :='||P_ACCOUNT_NUMBER;
                        V_ENV_INFO_TRACE.ERROR_CODE     := 'PWC-00021';

                        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                        RETURN (DECLARATION_CST.ERROR);
                END;
    END;
    EXCEPTION WHEN OTHERS
    THEN
            DECLARE
                V_ENV_INFO_TRACE            GLOBAL_VARS.ENV_INFO_TRACE_TYPE;
                BEGIN
                        V_ENV_INFO_TRACE.USER_NAME      :=  GLOBAL_VARS.USER_NAME;
                        V_ENV_INFO_TRACE.MODULE_CODE    :=  GLOBAL_VARS.ML_CREDIT_REVOLVING;
                        V_ENV_INFO_TRACE.PACKAGE_NAME   :=  $$PLSQL_UNIT;
                        V_ENV_INFO_TRACE.FUNCTION_NAME  :=  'GET_BASIC_CARD_FROM_ACCOUNT';
                        V_ENV_INFO_TRACE.LANG           :=  GLOBAL_VARS.LANG;
                        V_ENV_INFO_TRACE.USER_MESSAGE   :=  NULL;
                        PCRD_GENERAL_TOOLS.PUT_TRACES (V_ENV_INFO_TRACE,$$PLSQL_LINE);
                        RETURN (DECLARATION_CST.ERROR);
                END;

END GET_BASIC_CARD_FROM_ACCOUNT;
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNCTION        GENERATE_FILE                   (   p_business_date                 IN             DATE,   --NB30Aug2022 Date in filename generation
                                                                                                                p_file_seq              IN  OUT     NUMBER)

                                                    RETURN  PLS_INTEGER IS


v_filename              VARCHAR2(40);
f_xml_file              UTL_FILE.FILE_TYPE;
v_record_data           VARCHAR2(4000) := NULL;
v_env_info_trace        global_vars.env_info_trace_type;
v_total                 NUMBER;
counter                 NATURAL:=   0;
j                       NATURAL:=   1;

CURSOR      CUR_ICPS_MCIB_FILE
IS
    SELECT *
    FROM    ICPS_MCIB_FILE
    ORDER   by entity_code ;


BEGIN
    v_env_info_trace.user_name      :=  global_vars.USER_NAME;
    v_env_info_trace.module_code    :=  global_vars.ML_CARD;
    v_env_info_trace.package_name   :=  'PCRD_ICPS_GEN_MCBI_FILE';
    v_env_info_trace.function_name  :=  'GENERATE_FILE';
    v_env_info_trace.lang           :=  global_vars.LANG;
    p_file_seq                      :=  1000000;

    BEGIN
        SELECT  NVL(COUNT(*), 1)
        INTO    v_total
        FROM    ICPS_MCIB_FILE   ;
    END;

    FOR i IN 1 .. TRUNC(v_total/p_file_seq) + 1
    LOOP
        EXIT WHEN  j > p_file_seq * (counter +  1);

       /* NB30Aug2022 Date in filename generation
                v_filename      := 'SentCimC'||TO_CHAR(SYSDATE, 'DDMMYYYY')||'_'||TO_CHAR(counter, 'FM00')||'.xml';     --NB30Aug2022 Date in filename generation
                */
                v_filename      := 'SentCimC'||TO_CHAR(p_business_date, 'DDMMYYYY')||'_'||TO_CHAR(counter, 'FM00')||'.xml';     --NB30Aug2022 Date in filename generation
        f_xml_file      := UTL_FILE.FOPEN('OUT_DIR_CIM', v_filename, 'W');
        v_record_data   := '<?xml version="1.0" encoding="UTF-8"?>';

        UTL_FILE.PUT_LINE(f_xml_file, v_record_data);
        UTL_FILE.PUT_LINE(f_XML_FILE, '<MCIB>');

        UTL_FILE.put_line(f_XML_FILE, '<BANK grp_id="CIML">'); --BJH17062019

        FOR  v_icps_mcib_file    IN   CUR_ICPS_MCIB_FILE
        LOOP
--          select 'UTL_FILE.put_line(f_xml_file, ''<'||COLUMN_NAME ||' >'' || v_icps_mcib_file.'||COLUMN_NAME ||' || ''</'||COLUMN_NAME||'>'');' from ALL_TAB_COLUMNS  where table_name ='ICPS_MCIB_FILE' order by COLUMN_ID;
            UTL_FILE.PUT_LINE(F_XML_FILE, '<CREDIT record_status="' || v_icps_mcib_file.RECORD_STATUS ||'">');
            UTL_FILE.put_line(f_xml_file, '<ENTITY_CODE >' || v_icps_mcib_file.ENTITY_CODE || '</ENTITY_CODE>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<ENTITY_TYPE >' || v_icps_mcib_file.ENTITY_TYPE || '</ENTITY_TYPE>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<RESIDENT_FLAG >' || htf.escape_sc(v_icps_mcib_file.RESIDENT_FLAG) || '</RESIDENT_FLAG>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<ENTITY_NAME >' ||htf.escape_sc( v_icps_mcib_file.ENTITY_NAME )|| '</ENTITY_NAME>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<ENTITY_OTHER_NAME >' || htf.escape_sc(v_icps_mcib_file.ENTITY_OTHER_NAME) || '</ENTITY_OTHER_NAME>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<DOB >' || htf.escape_sc(v_icps_mcib_file.DOB )|| '</DOB>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<SEX >' || htf.escape_sc(v_icps_mcib_file.SEX )|| '</SEX>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<COUNTRY_CODE >' ||htf.escape_sc( v_icps_mcib_file.COUNTRY_CODE) || '</COUNTRY_CODE>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<PASSPORT_NO >' ||htf.escape_sc( v_icps_mcib_file.PASSPORT_NO) || '</PASSPORT_NO>');
            --REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( v_icps_mcib_file.ADDRESS1,'&' , '&amp;'),'`' , '&apos;'), '<' , '&lt;') ,'>','&gt;'),'"','&quot;') ;
            UTL_FILE.PUT_LINE(F_XML_FILE, '<ADDRESS1 >' || htf.escape_sc( v_icps_mcib_file.ADDRESS1) || '</ADDRESS1>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<ADDRESS2 >' || htf.escape_sc( v_icps_mcib_file.ADDRESS2) || '</ADDRESS2>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<ADDRESS3 >' || htf.escape_sc( v_icps_mcib_file.ADDRESS3) || '</ADDRESS3>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<ADDRESS4 >' || htf.escape_sc( v_icps_mcib_file.ADDRESS4)|| '</ADDRESS4>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<ADDRESS5 >' || htf.escape_sc( v_icps_mcib_file.ADDRESS5) || '</ADDRESS5>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<REF_NO >' || htf.escape_sc(v_icps_mcib_file.REF_NO )|| '</REF_NO>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<CREDIT_TYPE >' || htf.escape_sc(v_icps_mcib_file.CREDIT_TYPE )|| '</CREDIT_TYPE>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<DATE_APPROVED >' || htf.escape_sc(v_icps_mcib_file.DATE_APPROVED )|| '</DATE_APPROVED>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<PARENT_CO_NO >' ||htf.escape_sc( v_icps_mcib_file.PARENT_CO_NO )|| '</PARENT_CO_NO>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<PARENT_CO_NAME >' || htf.escape_sc(v_icps_mcib_file.PARENT_CO_NAME )|| '</PARENT_CO_NAME>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<SECTOR_LOAN_CLASS >' || htf.escape_sc(v_icps_mcib_file.SECTOR_LOAN_CLASS )|| '</SECTOR_LOAN_CLASS>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<CURR >' || htf.escape_sc(v_icps_mcib_file.CURR )|| '</CURR>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<AMOUNT_ORG >' || htf.escape_sc(v_icps_mcib_file.AMOUNT_ORG )|| '</AMOUNT_ORG>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<AMOUNT_OUT >' ||htf.escape_sc( v_icps_mcib_file.AMOUNT_OUT )|| '</AMOUNT_OUT>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<AMOUNT_DIS >' || htf.escape_sc(v_icps_mcib_file.AMOUNT_DIS )|| '</AMOUNT_DIS>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<DATE_UPDATE >' ||htf.escape_sc( v_icps_mcib_file.DATE_UPDATE )|| '</DATE_UPDATE>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<AMOUNT_INST >' || htf.escape_sc(v_icps_mcib_file.AMOUNT_INST )|| '</AMOUNT_INST>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<DATE_FIRST_INST >' || htf.escape_sc(v_icps_mcib_file.DATE_FIRST_INST )|| '</DATE_FIRST_INST>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<PERIODICITY >' || htf.escape_sc(v_icps_mcib_file.PERIODICITY )|| '</PERIODICITY>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<DATE_LAST_INST >' || htf.escape_sc(v_icps_mcib_file.DATE_LAST_INST )|| '</DATE_LAST_INST>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<DATE_EXP >' || htf.escape_sc(v_icps_mcib_file.DATE_EXP )|| '</DATE_EXP>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<NO_INST >' || htf.escape_sc(v_icps_mcib_file.NO_INST )|| '</NO_INST>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<DATE_DEFAULT >' ||htf.escape_sc( v_icps_mcib_file.DATE_DEFAULT )|| '</DATE_DEFAULT>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<BAL_DEFAULT >' || htf.escape_sc(v_icps_mcib_file.BAL_DEFAULT )|| '</BAL_DEFAULT>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<AMOUNT_ARRS >' || TO_CHAR(NVL(htf.escape_sc(v_icps_mcib_file.AMOUNT_ARRS ),NULL), 'FM999999990.00')|| '</AMOUNT_ARRS>'); --BJH17062019
            UTL_FILE.PUT_LINE(F_XML_FILE, '<TYPE_CLASS >' || htf.escape_sc(v_icps_mcib_file.TYPE_CLASS )|| '</TYPE_CLASS>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<FIRST_COLL >' || htf.escape_sc(v_icps_mcib_file.FIRST_COLL )|| '</FIRST_COLL>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<SECOND_COLL >' ||htf.escape_sc( v_icps_mcib_file.SECOND_COLL )|| '</SECOND_COLL>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<THIRD_COLL >' || htf.escape_sc(v_icps_mcib_file.THIRD_COLL )|| '</THIRD_COLL>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<FOURTH_COLL >' ||htf.escape_sc( v_icps_mcib_file.FOURTH_COLL )|| '</FOURTH_COLL>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<FIFTH_COLL >' || htf.escape_sc(v_icps_mcib_file.FIFTH_COLL )|| '</FIFTH_COLL>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<REMARKS >' ||htf.escape_sc( v_icps_mcib_file.REMARKS )|| '</REMARKS>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<RECORD_STATUS >' || htf.escape_sc(v_icps_mcib_file.RECORD_STATUS )|| '</RECORD_STATUS>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<UNIQUE_REF_ID >' || htf.escape_sc(v_icps_mcib_file.UNIQUE_REF_ID )|| '</UNIQUE_REF_ID>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<DATE_REGULARISED >' || htf.escape_sc(v_icps_mcib_file.DATE_REGULARISED )|| '</DATE_REGULARISED>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<ACTION_TAKEN >' || htf.escape_sc(v_icps_mcib_file.ACTION_TAKEN )|| '</ACTION_TAKEN>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '<ACTION_DATE >' ||htf.escape_sc( v_icps_mcib_file.ACTION_DATE )|| '</ACTION_DATE>');
            UTL_FILE.PUT_LINE(F_XML_FILE, '</CREDIT>');
            --UTL_FILE.PUT_LINE(F_XML_FILE, '<RECORD_STATUS >' || v_icps_mcib_file.RECORD_STATUS )|| '</RECORD_STATUS>');

        j := j + 1;
        END LOOP;
--        UTL_FILE.put_line(f_XML_FILE, '</HTML>');
        --UTL_FILE.PUT_LINE(F_XML_FILE, '</RECORD_STATUS>');

        UTL_FILE.put_line(f_XML_FILE, '</BANK>'); --BJH17062019

        UTL_FILE.PUT_LINE(f_XML_FILE, '</MCIB>');
        UTL_FILE.FCLOSE(f_xml_file);
        counter := counter + 1;

    END LOOP;

    RETURN(DECLARATION_CST.OK);

EXCEPTION
    WHEN UTL_FILE.INTERNAL_ERROR
    THEN
        v_env_info_trace.user_message   :=  'Cannot open file :' || v_filename ||
                                            ', internal error; code:' || sqlcode ||
                                            ',message:' || sqlerrm;
        PCRD_GENERAL_TOOLS.PUT_TRACES  (v_env_info_trace,$$PLSQL_LINE );
        RETURN(declaration_cst.ERROR);
    WHEN UTL_FILE.INVALID_OPERATION
    THEN
       v_env_info_trace.user_message   :=   'Cannot open file :' || v_filename ||
                                            ', invalid operation; code:' || sqlcode ||
                                            ',message:' || sqlerrm;
       PCRD_GENERAL_TOOLS.PUT_TRACES  (v_env_info_trace,$$PLSQL_LINE );
       RETURN(declaration_cst.ERROR);
    WHEN UTL_FILE.INVALID_PATH
    THEN
        v_env_info_trace.user_message   :=  'Cannot open file :' || v_filename ||
                                            ', invalid path; code:' || sqlcode ||
                                            ',message:' || sqlerrm;
        PCRD_GENERAL_TOOLS.PUT_TRACES  (v_env_info_trace,$$PLSQL_LINE );
        RETURN(declaration_cst.ERROR);
    WHEN UTL_FILE.WRITE_ERROR
    THEN
        v_env_info_trace.user_message   := 'Cannot write to file :' || v_filename ||
                                           ', write error; code:' || sqlcode ||
                                           ',message:' || sqlerrm;
        PCRD_GENERAL_TOOLS.PUT_TRACES  (v_env_info_trace,$$PLSQL_LINE );
        RETURN(declaration_cst.ERROR);
WHEN OTHERS
THEN
    v_env_info_trace.user_message   :=  'WHEN OTHERS EXCEPTION OCCURED; '||SUBSTR(SQLERRM,1,100);
    PCRD_GENERAL_TOOLS.PUT_TRACES  (v_env_info_trace,1000 );
    RETURN(declaration_cst.ERROR);
END GENERATE_FILE;
------------------------------------------------------------------------------------------------------------------------------------
--BJH14062019
FUNCTION    GET_LAST_TERM  ( p_shadow_account_nbr       IN              SHADOW_ACCOUNT.shadow_account_nbr%TYPE,
                             p_cr_term_record           IN OUT NOCOPY   CR_TERM%ROWTYPE )
                             RETURN PLS_INTEGER IS

v_env_info_trace                GLOBAL_VARS.ENV_INFO_TRACE_TYPE;
return_status                   PLS_INTEGER;
BEGIN
    v_env_info_trace.business_date  :=  BUSINESS_DATE$;
    v_env_info_trace.user_name      :=  GLOBAL_VARS.USER_NAME;
    v_env_info_trace.lang           :=  GLOBAL_VARS.LANG;
    v_env_info_trace.package_name   :=  'PCRD_ICPS_GEN_MCBI_FILE';
    v_env_info_trace.function_name  :=  'GET_LAST_TERM';

    BEGIN
        SELECT  *
        INTO    p_cr_term_record
        FROM
        (   SELECT   *
            FROM     V_CR_TERM_VIEW  --BJH14062019
            WHERE    shadow_account_nbr  =  p_shadow_account_nbr
            ORDER BY statement_date DESC
        )
        WHERE   ROWNUM = 1;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN

        RETURN DECLARATION_CST.OK;

    WHEN OTHERS THEN
        v_env_info_trace.user_message   :=  'ERROR WHEN GETTING THE CR_TERM'
                                        ||  ' ACCOUNT NUMBER : '    || p_shadow_account_nbr;
        PCRD_GENERAL_TOOLS.put_traces ( v_env_info_trace, $$PLSQL_LINE );
        RETURN  DECLARATION_CST.ERROR;
    END;
    RETURN DECLARATION_CST.OK;
EXCEPTION
WHEN OTHERS THEN
    v_env_info_trace.user_message   :=  'OTHERS ERROR : '   ||  SUBSTR(SQLERRM,1,100);
    PCRD_GENERAL_TOOLS.PUT_TRACES ( v_env_info_trace, $$PLSQL_LINE );
    RETURN  DECLARATION_CST.ERROR;
END GET_LAST_TERM;
------------------------------------------------------------------------------------------------------------------------------------
END     PCRD_ICPS_GEN_MCBI_FILE ;
/

-- Grants for Package Body
GRANT EXECUTE ON pcrd_icps_gen_mcbi_file TO dollaru_cf
/
GRANT EXECUTE ON pcrd_icps_gen_mcbi_file TO icps_power_cim
/


-- End of DDL Script for Package Body POWERIOV3.PCRD_ICPS_GEN_MCBI_FILE

