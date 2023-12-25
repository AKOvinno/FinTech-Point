-- Start of DDL Script for Package Body POWERV3FE.PCRD_P7_LOAD_ISS_DATA
-- Generated 07-Jun-2023 17:31:23 from POWERV3FE@(DESCRIPTION =(ADDRESS_LIST =(ADDRESS = (PROTOCOL = TCP)(HOST = 172.17.100.118)(PORT = 1521)))(CONNECT_DATA =(SERVICE_NAME = mcbprdfe)))

CREATE OR REPLACE 
PACKAGE BODY pcrd_p7_load_iss_data --ADIL
IS
  ------------------------------------------------------------------------------------------------------------------------------------------------
   -- Person        Version  Ref              Date           Comments
   ------------------------------------------------------------------------------------------------------------------------------------------------
   -- Y.DAHMANE      3.0.0   YDA20170608       08/06/2017     ADD account_level See YDA20170608 (PROD00037187)
   -- J.OUADIM       3.0.1   JOU20170623       23/06/2017     ADD the call GET_FRAUD_CTRL_PARAM see PROD00044028
   -- I.CHAKOUR      3.0.2   ICH20170809       09/08/2017     See ICH20170809 (PROD00045701)The acquirer bank code parameterized in (Acq_bank_network) is not set by bank
   -- I.CHAKOUR      3.0.3   ICH20170831       31/08/2017     See ICH20170831(PROD00046480) complement of ICH20170809
   -- I.CHAKOUR      3.0.4   ICH20170913       31/08/2017     See ICH20170913(PROD00046796)
    --I.CHAKOUR      3.0.5   ICH20170927       27/09/2017     ADD TAG DB_CARD_SEQ_NO ICH20170927 (PROD00047340)
--V3DEBITMIG
   ------------------------------------------------------------------------------------------------------------------------------------------------
FUNCTION LOAD_ISSUER_DATA (         p_card_number               IN              CARD.card_number%TYPE,
                                    p_tlv_data                  IN OUT NOCOPY   VARCHAR2)
                                    RETURN  PLS_INTEGER IS
return_status                       PLS_INTEGER;
v_card_range_rec                    CARD_RANGE%ROWTYPE;
v_card_rec                          CARD%ROWTYPE;
v_card_type_record                  CARD_TYPE%ROWTYPE;
v_card_product_rec                  CARD_PRODUCT%ROWTYPE;
v_p7_autho_period_record            P7_AUTHO_PERIOD%ROWTYPE;
Spy_counter                         PLS_INTEGER;
v_acquirer_bank                     AUTHO_ACTIVITY_ADM.acquirer_bank%TYPE;
v_origine_code                      AUTHO_ACTIVITY_ADM.origine_code%TYPE;
v_length_tag                        PLS_INTEGER;
v_routing_code                      AUTHO_ACTIVITY_ADM.routing_code%TYPE;
v_onus_nat_inter_flag               CHAR(5);
v_processing_code                   AUTHO_ACTIVITY_ADM.processing_code%TYPE;
v_error                             PLS_INTEGER;
v_tag_value                         VARCHAR2(4096);
v_loc_tlv                           VARCHAR2(4096);
v_index_application_code            CARD_PRODUCT.icc_application_index%type;
v_env_info_trace                    global_vars.env_info_trace_type;
v_message_type                      AUTHO_ACTIVITY_ADM.message_type%TYPE;
v_emv_icc_appl_param_rec            EMV_ICC_APPLICATION_PARAM%ROWTYPE;
v_emv_card_info_param               VARCHAR2(256);
v_appl_id                           VARCHAR2(6);
v_iad_fmt                           CHAR(2);
v_pin_unblk_opt                     CHAR(1);
v_pin_chg_opt                       CHAR(1);
v_arpc_mthd                         CHAR(1);
v_crd_key_drv_mthd                  CHAR(1);
v_sk_drv_mthd                       CHAR(1);
v_ofln_pin_opt                      CHAR(1);
v_ucol                              VARCHAR2(8);
v_count                             PLS_INTEGER;
v_sec_verif_level                   autho_activity_adm.security_verif_level%TYPE;
v_p7_limits_setup_tot_rec           P7_LIMITS_SETUP_TOTAL%ROWTYPE;
v_cvv2_retry_max                    CONTROL_VERIFICATION_FLAGS.cvv2_retry_max%TYPE;
v_exp_date_retry_max                CONTROL_VERIFICATION_FLAGS.exp_date_retry_max%TYPE;
v_aid                               VARCHAR2(64);--SNO211215
v_icc_application_code              EMV_KEYS_ASSIGNMENT.icc_application_code%TYPE;--SNO211215
v_tag_len                           PLS_INTEGER;

v_balance_level                     AUTHO_ACTIVITY_ADM.balance_level%TYPE;
v_shadow_account_level              AUTHO_ACTIVITY_ADM.shadow_account_level%TYPE;
v_account_level                     CHAR(1);--YDA20170608
--v_shadow_account_nbr                SHADOW_ACCOUNT.shadow_account_nbr%TYPE;
v_credit_auth_param_rec             CREDIT_AUTH_PARAM%ROWTYPE;
v_card_auth_opt                     P7_GLOBAL_VARS.ISS_AUTH_INFO;
v_cr_auth_opt                       CHAR(1);
v_payment_auth_info                 P7_GLOBAL_VARS.PAYMENT_AUTH_OPT;
v_fraud_ctrl_param                  P7_GLOBAL_VARS.FRAUD_CTRL_PARAM;
--v_vel_chk_opt                       CHAR(1);
v_icc_app_par_index_rec             ICC_APPLICATION_PAR_INDEX%ROWTYPE;
v_chip_iad                          AUTHO_ACTIVITY_ADM.chip_issuer_application_data%TYPE; --PROD00036768
v_cvr                               AUTHO_ACTIVITY_ADM.chip_issuer_application_data%TYPE;

/*Start ICH20170809*/
v_acq_bank_network_rec              ACQ_BANK_NETWORK%ROWTYPE;
v_acquirer_network_code             AUTHO_ACTIVITY_ADM.network_code%TYPE;
v_priv_data                         AUTHO_ACTIVITY_ADM.private_tlv_data%TYPE;
v_acq_bank_pvt_data                 AUTHO_ACTIVITY_ADM.private_tlv_data%TYPE;
v_acquirer_institution_code         AUTHO_ACTIVITY_ADM.acquirer_institution_code%TYPE;
v_card_acceptor_term_id             AUTHO_ACTIVITY_ADM.card_acceptor_term_id%TYPE;
v_card_acceptor_id                  AUTHO_ACTIVITY_ADM.card_acceptor_id%TYPE;
/*End ICH20170809*/

v_is_chip_card                      BOOLEAN := FALSE;
/*RAM MCB CYCLE 3 Custo*/
v_len_tag                           PLS_INTEGER;
v_country_code                      VARCHAR2(10):= NULL;
v_network_code                      AUTHO_ACTIVITY_ADM.NETWORK_CODE%TYPE;
v_field_043                         VARCHAR2(64):= NULL;
--added on mtp 04/05/2023
v_powercard_globals_rec             POWERCARD_GLOBALS%ROWTYPE;

BEGIN

    -- Chargement avec le maximum d'information dans la structure TLV
    -- . NETWORK_CODE *
    -- . ISSUING_BANK *
    -- . START_EXPIRY_DATE *
    -- . PRODUCT_CODE *
    -- . CARD_TYPE *
    -- . VIP_LEVEL *
    -- . SERVICES_SETUP_CODE *
    -- . PRODUCT_CURRENCY_CODE *
    -- . LIMITS_INDEXES *
    -- . PERIOD_CODE *
    -- . PERIOD_TYPE *
    -- . PERIOD_VALUE *
    -- . vip_action_translation_level
    -- . RECEIVING_INSTITUTION *
    -- . CARD_LEVEL
    -- . ACTION_TRANSLATION_LEVEL
    -- . CARD_LIMIT_EXCEPTION_LEVEL
    -- . VIP_ACTION_TRANSLATION_LEVEL
    -- . AUTHO_PERIOD_LEVEL
    -- . SCENARION CODE
    -- . PIN RETRY MAX
    -- . ORIGIN CODE

    v_env_info_trace.user_name      :=  global_vars.USER_NAME;
    v_env_info_trace.module_code    :=  global_vars.ML_AUTHORIZATION;
    v_env_info_trace.lang           :=  global_vars.LANG;
    v_env_info_trace.package_name   :=  $$PLSQL_UNIT;
    v_env_info_trace.function_name  :=  'LOAD_ISSUER_DATA';


    return_status := PCRD_CARD_PARAM_DATA.GET_CARD_RANGE (  p_card_number,
                                                            v_card_range_rec,
                                                            FALSE
                                                         );

    IF return_status <> Declaration_cst.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.PUT_EVENT(p_tlv_data,
                                         event_global_vars.ISSUER_UNKNOWN,
                                         'Error Getting Card Range' );
        RETURN(return_status);
    END IF;

    IF v_card_range_rec.get_card_data_level = 'Y'
    THEN
        return_status := PCRD_CARD_DATA.GET_CARD    (   p_card_number,
                                                        v_card_rec
                                                        );
        IF return_status != DECLARATION_CST.OK
        THEN
            PCRD_P7_GENERAL_TOOLS.PUT_EVENT(    p_tlv_data,
                                                event_global_vars.CARD_NOT_FOUND,
                                                'Card Not Found');
            RETURN(DECLARATION_CST.NOK);
        END IF;

        return_status :=  PCRD_CARD_PARAM_DATA.GET_CARD_PRODUCT (   v_card_rec.bank_code,
                                                                    v_card_rec.card_product_code,
                                                                    v_card_product_rec
                                                                    );
        IF return_status != DECLARATION_CST.OK
        THEN
            PCRD_P7_GENERAL_TOOLS.PUT_EVENT(p_tlv_data,
                                            event_global_vars.CARD_NOT_FOUND,
                                            'Card Product Not Found(GET_CARD_DATA_LEVEL)');
             RETURN(DECLARATION_CST.NOK);
        END IF;
    ELSIF v_card_range_rec.get_product_data_level = 'Y'
    THEN
       IF v_card_range_rec.single_product_flag = 'N'
       THEN

            return_status := PCRD_CARD_DATA.GET_CARD    (   p_card_number,
                                                            v_card_rec
                                                         );
            IF return_status != DECLARATION_CST.OK
            THEN
                PCRD_P7_GENERAL_TOOLS.PUT_EVENT(    p_tlv_data,
                                                    event_global_vars.CARD_NOT_FOUND,
                                                    'Card Not Found');
                RETURN(DECLARATION_CST.NOK);
            END IF;

            return_status :=  PCRD_CARD_PARAM_DATA.GET_CARD_PRODUCT (   v_card_rec.bank_code,
                                                                        v_card_rec.card_product_code,
                                                                        v_card_product_rec
                                                                          );

            IF return_status != DECLARATION_CST.OK
            THEN
                 PCRD_P7_GENERAL_TOOLS.PUT_EVENT(   p_tlv_data,
                                                    event_global_vars.CARD_NOT_FOUND,
                                                    'Card Product Not Found(SINGLE_PRODUCT_FLAG)');
                RETURN(DECLARATION_CST.NOK);
            END IF;
        ELSE
            return_status :=  PCRD_CARD_PARAM_DATA.GET_CARD_PRODUCT (   v_card_range_rec.issuing_bank_code,
                                                                        v_card_range_rec.product_code,
                                                                        v_card_product_rec
                                                                      );
            IF return_status != DECLARATION_CST.OK
            THEN
                PCRD_P7_GENERAL_TOOLS.PUT_EVENT(p_tlv_data,
                                                event_global_vars.CARD_NOT_FOUND,
                                                'Card Product Not Found(GET_PRODUCT_DATA_LEVEL)');
                 RETURN(DECLARATION_CST.NOK);
            END IF;
        END IF;
    END IF; -- Card Level
    /*VV25012023 CHANGES FOR PRE-PAID BAL ENQ PRINT RECEIPT START*/
    Return_Status   := PCRD_GET_PARAM_GENERAL_ROWS_2.GET_POWERCARD_GLOBALS (    'LOCAL_BANK',
                                            v_powercard_globals_rec );
    IF Return_Status <> declaration_cst.OK
    THEN
        v_env_info_trace.user_message   :=  'ERROR RETURNED BY PCRD_GET_PARAM_GENERAL_ROWS_2.GET_POWERCARD_GLOBALS'
                                        ||  ', VARIABLE NAME : LOCAL_BANK';
        PCRD_GENERAL_TOOLS.PUT_TRACES  (v_env_info_trace, $$PLSQL_LINE );
        RETURN  Return_Status;
    END IF;
 IF v_card_range_rec.issuing_bank_code = v_powercard_globals_rec.variable_value 
 THEN   
return_status :=  PCRD_CARD_PARAM_DATA.GET_CARD_PRODUCT (   v_card_range_rec.issuing_bank_code,
                                                                        v_card_range_rec.product_code,
                                                                        v_card_product_rec
                                                                      );
END IF;                                                                      
    /*VV25012023 CHANGES FOR PRE-PAID BAL ENQ PRINT RECEIPT END*/

    IF v_card_range_rec.get_card_data_level = 'Y'
    THEN
        --Niveau carte ( chercher le record card).

        v_card_range_rec.issuing_bank_code              :=v_card_rec.bank_code;
        v_card_range_rec.limits_indexes                 :=v_card_rec.limits_indexes;
        v_card_range_rec.periodicity_code               :=v_card_rec.periodicity_code ;
        v_card_range_rec.vip_response_translation       :=v_card_rec.vip_level ;

        v_index_application_code                        :=v_card_rec.icc_application_index;


        v_card_range_rec.network_code                   :=v_card_product_rec.network_code;
        v_card_range_rec.product_code                   :=v_card_product_rec.product_code;
        v_card_range_rec.currency_code                  :=v_card_product_rec.currency_code;
        v_card_range_rec.services_setup_index           :=v_card_product_rec.services_setup_index;
        v_card_range_rec.control_verification_index     :=v_card_product_rec.control_verification_index ;
        v_card_range_rec.service_code                   :=v_card_product_rec.service_code ;
        v_card_range_rec.currency_code                  :=v_card_product_rec.currency_code ;

        v_card_range_rec.issuer_bin                     :=v_card_range_rec.issuer_bin ;

    ELSIF v_card_range_rec.get_product_data_level = 'Y'
    THEN
    --    Niveau produit ( chercher le record product).

        v_card_range_rec.issuing_bank_code              :=v_card_product_rec.bank_code;
        v_card_range_rec.network_code                   :=v_card_product_rec.network_code;
        v_card_range_rec.product_code                   :=v_card_product_rec.product_code;
        v_card_range_rec.limits_indexes                 :=v_card_product_rec.limits_indexes;
        v_card_range_rec.currency_code                  :=v_card_product_rec.currency_code;
        v_card_range_rec.periodicity_code               :=v_card_product_rec.periodicity_code ;
        v_card_range_rec.services_setup_index           :=v_card_product_rec.services_setup_index;
        v_card_range_rec.control_verification_index     :=v_card_product_rec.control_verification_index ;
        v_card_range_rec.service_code                   :=v_card_product_rec.service_code ;
        v_card_range_rec.currency_code                  :=v_card_product_rec.currency_code ;
        v_index_application_code                        :=v_card_product_rec.icc_application_index;
    END IF;


    v_loc_tlv := p_tlv_data;
----------------------------------------------------------------------------------------
    -- NETWORK_CODE
-----------------------------------------------------------------------------------------

    Spy_counter := 0;
    IF ( v_card_range_rec.network_code IS NULL )
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                       'Err Load Iss Data : NETWORK_CODE' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

    Spy_counter := 1;
    return_status := PCRD_TAG_PROCESSING.PUT_TAG (      PCRD_TAG_PROCESSING.NETWORK_CODE          ,
                                                        v_card_range_rec.network_code     ,
                                                        p_tlv_data
                                             );
    IF return_status != DECLARATION_CST.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : Ins Tag' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;
----------------------------------------------------------------------------------------
    -- ICC_APPLICATION_INDEX
-----------------------------------------------------------------------------------------
    -- Start SNO211215
    v_aid          :=  PCRD_TAG_PROCESSING.EXTRACT_TLV_FROM_BUFFER ( PCRD_TAG_PROCESSING.chip_application_identifier,
                                                                          v_error,
                                                                          v_tag_len,
                                                                          v_tag_value,
                                                                          --p_tlv_data);--SNO211215
                                                                          v_loc_tlv);--PROXX: Should not remove this tag from original tlv
    IF v_error <> declaration_cst.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                    event_global_vars.INVALID_ISSUER_DATA ,
                                                    'Error extract chip_application_identifier ');
        RETURN(DECLARATION_CST.NOK);
    END IF;




    IF  v_aid  IS NOT NULL
    OR v_index_application_code IS NULL --PROD00032359
    THEN
        --PROD00030997
        Return_Status := PCRD_EMV_PARAM_DATA.GET_EMV_MULTI_APP_CR_PARAM          (  v_card_range_rec.issuing_bank_code,
                                               p_card_number,
                                               v_aid ,
                                               v_icc_application_code
                                            );
        IF Return_Status = declaration_cst.ERROR
        THEN
            v_env_info_trace.user_message := 'ERROR RETURNED PCRD_EMV_PARAM_DATA.GET_EMV_MULTI_APP_CR_PARAM';
            PCRD_GENERAL_TOOLS.PUT_TRACES (v_env_info_trace,$$PLSQL_LINE);
            RETURN Return_Status;
        ELSIF Return_Status = declaration_cst.OK
        THEN
            v_index_application_code := v_icc_application_code;
        END IF;
    END IF;


    -- End SNO211215
    IF ( v_index_application_code   IS NOT NULL )
    THEN

        return_status := PCRD_TAG_PROCESSING.PUT_TAG (      PCRD_TAG_PROCESSING.ICC_APPLICATION_INDX          ,
                                                            v_index_application_code,
                                                            p_tlv_data
                                                 );
        IF return_status != DECLARATION_CST.OK
        THEN
            PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                            event_global_vars.INVALID_ISSUER_DATA ,
                                                            'Err Load Iss Data : Ins Tag ICC_APPLICATION_INDEX');
            RETURN(DECLARATION_CST.NOK);
        END IF;
    END IF;



----------------------------------------------------------------------------------------
    -- . ISSUING_BANK *
----------------------------------------------------------------------------------------
    Spy_counter := 2;
    IF ( v_card_range_rec.issuing_bank_code IS NULL )
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : ISS_BANK' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

    return_status := PCRD_TAG_PROCESSING.PUT_TAG (      PCRD_TAG_PROCESSING.ISSUING_BANK ,
                                                        v_card_range_rec.issuing_bank_code ,
                                                        p_tlv_data
                                             );
    IF return_status != DECLARATION_CST.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : Ins Tag ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

----------------------------------------------------------------------------------------
    --  CONTROL_VERIF_INDEX
----------------------------------------------------------------------------------------
    Spy_counter := 3;

    IF ( v_card_range_rec.control_verification_index IS NULL )
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.ERROR_SEC_FLAG ,
                                                        'Control Verification Flags Missing : ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

    return_status := PCRD_TAG_PROCESSING.PUT_TAG (      PCRD_TAG_PROCESSING.CONTROL_VERIF_INDEX ,
                                                        v_card_range_rec.control_verification_index ,
                                                        p_tlv_data
                                             );
    IF return_status != DECLARATION_CST.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : Ins Tag ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;



----------------------------------------------------------------------------------------
    -- 22. START_EXPIRY_DATE
----------------------------------------------------------------------------------------
    Spy_counter := 4;

    IF v_card_range_rec.GET_CARD_DATA_LEVEL = 'Y'
    THEN
        Spy_counter := 5;
        -- HYJCC150502
        return_status := PCRD_TAG_PROCESSING.PUT_TAG (      PCRD_TAG_PROCESSING.START_EXPIRY_DATE      ,
                                                            --p_enr_card.START_VAL_DATE ,
                                                            TO_CHAR(v_card_rec.start_val_date,'RRMM') ,
                                                            p_tlv_data
                                                    );
        IF return_status != DECLARATION_CST.OK
        THEN
            PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                            event_global_vars.INVALID_ISSUER_DATA ,
                                                            'Err Load Iss Data : Ins Tag' || PCRD_TAG_PROCESSING.START_EXPIRY_DATE);
            RETURN(DECLARATION_CST.NOK);
        END IF;

        --Start EBE141016
        return_status := PCRD_TAG_PROCESSING.GET_TAG   (
                                                         PCRD_TAG_PROCESSING.END_EXPIRY_DATE  ,
                                                         p_tlv_data                      ,
                                                         v_length_tag,
                                                         v_tag_value
                                                        );
        IF return_status != DECLARATION_CST.OK
        THEN
            return_status := PCRD_TAG_PROCESSING.PUT_TAG (      PCRD_TAG_PROCESSING.END_EXPIRY_DATE    ,
                                                                TO_CHAR(v_card_rec.expiry_date,'RRMM') ,
                                                                p_tlv_data
                                                        );
            IF return_status != DECLARATION_CST.OK
            THEN
                PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                                event_global_vars.INVALID_ISSUER_DATA ,
                                                                'Err Load Iss Data : Ins Tag' || PCRD_TAG_PROCESSING.END_EXPIRY_DATE);
                RETURN(DECLARATION_CST.NOK);
            END IF;
        END IF;

  /*      return_status := PCRD_TAG_PROCESSING.GET_TAG   (
                                                         PCRD_TAG_PROCESSING.CARD_SEQUENCE_NUMBER  ,
                                                         p_tlv_data                      ,
                                                         v_length_tag,
                                                         v_tag_value
                                                        );
        IF return_status != DECLARATION_CST.OK
        THEN
            return_status := PCRD_TAG_PROCESSING.PUT_TAG (      PCRD_TAG_PROCESSING.CARD_SEQUENCE_NUMBER    ,
                                                                TO_CHAR(v_card_rec.card_seq,'FM000') ,
                                                                p_tlv_data
                                                        );
            IF return_status != DECLARATION_CST.OK
            THEN
                PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                                event_global_vars.INVALID_ISSUER_DATA ,
                                                                'Err Load Iss Data : Ins Tag' || PCRD_TAG_PROCESSING.CARD_SEQUENCE_NUMBER);
                RETURN(DECLARATION_CST.NOK);
            END IF;
        END IF;
*/

--Start ICH20170927
        return_status := PCRD_TAG_PROCESSING.PUT_TAG (      PCRD_TAG_PROCESSING.DB_CARD_SEQ_NO    ,
                                                            TO_CHAR(v_card_rec.card_seq,'FM000') ,
                                                            p_tlv_data
                                                    );
        IF return_status != DECLARATION_CST.OK
        THEN
            PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                            event_global_vars.INVALID_ISSUER_DATA ,
                                                            'Err Load Iss Data : Ins Tag' || PCRD_TAG_PROCESSING.CARD_SEQUENCE_NUMBER);
            RETURN(DECLARATION_CST.NOK);
        END IF;
 --End  ICH20170927
        --End EBE141016
    END IF;

----------------------------------------------------------------------------------------
    -- PRODUCT_CODE *
----------------------------------------------------------------------------------------
    Spy_counter := 6;
    IF ( v_card_range_rec.product_code IS NOT NULL )
    THEN
       return_status := PCRD_TAG_PROCESSING.PUT_TAG (   PCRD_TAG_PROCESSING.PRODUCT_CODE ,
                                                        v_card_range_rec.product_code ,
                                                        p_tlv_data
                                                    );
        IF return_status != DECLARATION_CST.OK
        THEN
            PCRD_P7_GENERAL_TOOLS.put_event(        p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : Ins Tag' || Spy_counter);
            RETURN(DECLARATION_CST.NOK);
        END IF;
    END IF;

----------------------------------------------------------------------------------------
    --  CARD_TYPE
----------------------------------------------------------------------------------------
    Spy_counter := 7;
    IF ( v_card_range_rec.network_card_type IS NULL )
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : NETWORK CARD TYPE' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

    Spy_counter := 9;
    return_status := PCRD_CARD_PARAM_DATA.GET_CARD_TYPE (       v_card_range_rec.network_code,
                                                                v_card_range_rec.issuing_bank_code,--ATE19082013
                                                                v_card_range_rec.network_card_type,
                                                                v_card_type_record
                                                            );
    IF return_status != DECLARATION_CST.OK
    THEN

        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data GET CARD TYPE: '||v_card_range_rec.network_code||'X'||v_card_range_rec.network_card_type );
        RETURN(DECLARATION_CST.NOK);
    END IF;


    Spy_counter := 10;
    IF ( v_card_type_record.network_card_type IS NULL )
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : CARD TYPE ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

    Spy_counter := 11;
    return_status := PCRD_TAG_PROCESSING.PUT_TAG (       PCRD_TAG_PROCESSING.CARD_TYPE    ,
                                                        v_card_type_record.network_card_type ,
                                                        p_tlv_data
                                                    );
    IF return_status != DECLARATION_CST.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : Ins Tag' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;


----------------------------------------------------------------------------------------
      -- 61. PERIOD_CODE
----------------------------------------------------------------------------------------
    Spy_counter := 12;
    IF ( v_card_range_rec.periodicity_code IS NULL )
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : PERIODICITY_CODE' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

    Spy_counter := 13;
    return_status := PCRD_TAG_PROCESSING.PUT_TAG (       PCRD_TAG_PROCESSING.PERIOD_CODE  ,
                                                        v_card_range_rec.periodicity_code    ,
                                                        p_tlv_data
                                                    );
    IF return_status != DECLARATION_CST.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : Ins Tag ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

----------------------------------------------------------------------------------------
     --  LIMITS_INDEXES
----------------------------------------------------------------------------------------
    Spy_counter := 14;
    IF ( v_card_range_rec.limits_indexes IS NULL )
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : LIMIT_INDEX ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

    Spy_counter := 15;
    return_status := PCRD_TAG_PROCESSING.PUT_TAG (      PCRD_TAG_PROCESSING.LIMIT_INDEX ,
                                                        v_card_range_rec.limits_indexes  ,
                                                        p_tlv_data
                                                );
    IF return_status != DECLARATION_CST.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : Ins Tag ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

----------------------------------------------------------------------------------------
     --  SERVICES_SETUP_CODE
----------------------------------------------------------------------------------------
    Spy_counter := 16;
    IF ( v_card_range_rec.services_setup_index IS NULL )
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : SERVICES_SETUP_INDEX ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

    Spy_counter := 17;
    return_status := PCRD_TAG_PROCESSING.PUT_TAG (       PCRD_TAG_PROCESSING.SERVICES_SETUP_CODE ,
                                                        v_card_range_rec.services_setup_index  ,
                                                        p_tlv_data
                                                );
    IF return_status != DECLARATION_CST.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : Ins Tag ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

----------------------------------------------------------------------------------------
    --. PRODUCT_CURRENCY_CODE
----------------------------------------------------------------------------------------
    Spy_counter := 18;
    IF ( v_card_range_rec.currency_code IS NULL )
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : CURRENCY ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

    Spy_counter := 19;
    return_status := PCRD_TAG_PROCESSING.PUT_TAG (       PCRD_TAG_PROCESSING.PRODUCT_CURRENCY_CODE ,
                                                        v_card_range_rec.currency_code  ,
                                                        p_tlv_data
                                                );
    IF return_status != DECLARATION_CST.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : Ins Tag ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

----------------------------------------------------------------------------------------
    -- . PERIOD_TYPE
----------------------------------------------------------------------------------------
    Spy_counter := 20;
    IF ( v_card_range_rec.periodicity_code IS NULL )
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : PERIODICITY_CODE ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

    Spy_counter := 21;



    v_processing_code :=  PCRD_TAG_PROCESSING.EXTRACT_TLV_FROM_BUFFER (
                                                                        PCRD_TAG_PROCESSING.PROCESSING_CODE,
                                                                        v_error,
                                                                        v_length_tag,
                                                                        v_tag_value,
                                                                        v_loc_tlv);
    -------------
    return_status := PCRD_LIMITS_PARAM_DATA.GET_P7_AUTHO_PERIOD (   v_card_range_rec.periodicity_code,
                                                                    v_p7_autho_period_record             ,
                                                                    FALSE
                                                                        );
    IF return_status != DECLARATION_CST.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : Get Period ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;


----------------------------------------------------------------------------------------
    -- Period Type
----------------------------------------------------------------------------------------
    Spy_counter := 22;
    IF ( v_p7_autho_period_record.period_type IS NULL )
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : PERIOD_TYPE ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

    Spy_counter := 23;
    return_status := PCRD_TAG_PROCESSING.PUT_TAG (       PCRD_TAG_PROCESSING.PERIOD_TYPE ,
                                                        v_p7_autho_period_record.period_type  ,
                                                        p_tlv_data
                                                );
    IF return_status != DECLARATION_CST.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : Ins Tag ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

----------------------------------------------------------------------------------------
    --. PERIOD_Day_OF
----------------------------------------------------------------------------------------
    Spy_counter := 24;
    IF ( v_p7_autho_period_record.period_day_of IS NULL AND v_p7_autho_period_record.period_type = 'W' )
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : PERIOD_VALUE ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

    Spy_counter := 25;
    return_status := PCRD_TAG_PROCESSING.PUT_TAG (       PCRD_TAG_PROCESSING.period_day_of ,
                                                        NVL(v_p7_autho_period_record.period_day_of,0)  ,
                                                        p_tlv_data
                                                    );
    IF return_status != DECLARATION_CST.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : Ins Tag ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

----------------------------------------------------------------------------------------
    --. PERIOD Value
----------------------------------------------------------------------------------------

    Spy_counter := 25;
    return_status := PCRD_TAG_PROCESSING.PUT_TAG (      PCRD_TAG_PROCESSING.period_value ,
                                                        NVL(v_p7_autho_period_record.period_value,0)  ,
                                                        p_tlv_data
                                                    );
    IF return_status != DECLARATION_CST.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : Ins Tag ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

----------------------------------------------------------------------------------------
    --. RECEIVING_INSTITUTION
----------------------------------------------------------------------------------------
    Spy_counter := 26;
    IF ( v_card_range_rec.issuer_bin IS NULL )
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : ISSUER_BIN ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

    Spy_counter := 27;
    return_status := PCRD_TAG_PROCESSING.PUT_TAG (       PCRD_TAG_PROCESSING.RECEIVING_INSTITUTION ,
                                                        v_card_range_rec.issuer_bin  ,
                                                        p_tlv_data
                                                );
    IF return_status != DECLARATION_CST.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : INS Tag ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

----------------------------------------------------------------------------------------
    --. CARD_LEVEL
----------------------------------------------------------------------------------------
    Spy_counter := 28;
    IF ( v_card_range_rec.get_card_data_level IS NULL )
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : GET_CARD_DATA_LEVEL ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

    Spy_counter := 29;
    return_status := PCRD_TAG_PROCESSING.PUT_TAG (       PCRD_TAG_PROCESSING.CARD_LEVEL ,
                                                        v_card_range_rec.get_card_data_level  ,
                                                        p_tlv_data
                                                    );
    IF return_status != DECLARATION_CST.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : Ins Tag ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;


----------------------------------------------------------------------------------------
    --. SCENARIO CODE
----------------------------------------------------------------------------------------
        Spy_counter := 35;
   IF v_card_product_rec.SCENARIO_CODE IS NOT NULL
   THEN
       return_status := PCRD_TAG_PROCESSING.PUT_TAG (   PCRD_TAG_PROCESSING.SCENARIO_CODE ,
                                                        v_card_product_rec.SCENARIO_CODE  ,
                                                        p_tlv_data
                                                );
        IF return_status != DECLARATION_CST.OK
        THEN
            PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : Ins Tag ' || Spy_counter);
            RETURN(DECLARATION_CST.NOK);
        END IF;
    END IF;

Spy_counter := 350;

   IF v_card_product_rec.product_type IS NOT NULL
   THEN
       return_status := PCRD_TAG_PROCESSING.PUT_TAG (   PCRD_TAG_PROCESSING.card_product_type ,
                                                        v_card_product_rec.product_type  ,
                                                        p_tlv_data
                                                );
        IF return_status != DECLARATION_CST.OK
        THEN
            PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : Ins Tag ' || Spy_counter);
            RETURN(DECLARATION_CST.NOK);
        END IF;
    END IF;

----------------------------------------------------------------------------------------
    -- . PIN RETRY MAX
----------------------------------------------------------------------------------------
    Spy_counter := 36;
    IF v_card_range_rec.pin_retry_max IS NOT NULL
    THEN
       return_status := PCRD_TAG_PROCESSING.PUT_TAG (   PCRD_TAG_PROCESSING.PIN_RETRY_MAX ,
                                                        v_card_range_rec.pin_retry_max  ,
                                                        p_tlv_data
                                                    );
        IF return_status != DECLARATION_CST.OK
        THEN
            PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : Ins Tag ' || Spy_counter);
            RETURN(DECLARATION_CST.NOK);
        END IF;
    END IF;

----------------------------------------------------------------------------------------
    -- . Database Service Code
----------------------------------------------------------------------------------------
    Spy_counter := 37;
    IF v_card_range_rec.service_code IS NOT NULL
    THEN
       return_status := PCRD_TAG_PROCESSING.PUT_TAG (   PCRD_TAG_PROCESSING.DB_SERVICE_CODE ,
                                                        v_card_range_rec.service_code  ,
                                                        p_tlv_data
                                                    );
        IF return_status != DECLARATION_CST.OK
        THEN
            PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : Ins Tag ' || Spy_counter);
            RETURN(DECLARATION_CST.NOK);
        END IF;
    END IF;


  ----------------------------------------------------------------------------------------
    -- . VIP RESPONSE TRANSLATION
----------------------------------------------------------------------------------------

    Spy_counter := 38;
    IF v_card_range_rec.vip_response_translation IS NOT NULL
    THEN
        return_status := PCRD_TAG_PROCESSING.PUT_TAG (   PCRD_TAG_PROCESSING.vip_level ,
                                                        v_card_range_rec.vip_response_translation  ,
                                                        p_tlv_data
                                                    );
        IF return_status != DECLARATION_CST.OK
        THEN
            PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : Ins Tag ' || Spy_counter);
            RETURN(DECLARATION_CST.NOK);
        END IF;
    END IF;


----------------------------------------------------------------------------------------
    -- . ACQUIRER BANK
----------------------------------------------------------------------------------------
    Spy_counter := 39;
    return_status := PCRD_TAG_PROCESSING.GET_TAG (   PCRD_TAG_PROCESSING.ACQUIRER_BANK ,
                                                    p_tlv_data  ,
                                                    v_length_tag,
                                                    v_acquirer_bank
                                                );
    IF return_status != DECLARATION_CST.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                    event_global_vars.TLV_ERROR_DATA ,
                                                    'Err Load Get Data : Ins Tag ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;
/*Start ICH20170809*/
    return_status := PCRD_TAG_PROCESSING.GET_TAG    (  PCRD_TAG_PROCESSING.private_tlv_data,
                                                        p_tlv_data,
                                                        v_length_tag,
                                                        v_priv_data);

    v_priv_data := TO_CHAR(LENGTH(v_priv_data),'FM0000')||v_priv_data;

    return_status := PCRD_TAG_PROCESSING.GET_TAG    (  PCRD_TAG_PROCESSING.PRIV_ACQUIRER_NETWORK_CODE,
                                                       v_priv_data,
                                                       v_length_tag,
                                                       v_acquirer_network_code);

    return_status := PCRD_TAG_PROCESSING.GET_TAG    (  PCRD_TAG_PROCESSING.PRIV_PVT_DATA_TAG,
                                                       v_priv_data,
                                                       v_length_tag,
                                                       v_acq_bank_pvt_data);


    return_status := PCRD_TAG_PROCESSING.GET_TAG    (  PCRD_TAG_PROCESSING.ACQUIRER_INSTITUTION_CODE,
                                                        p_tlv_data,
                                                        v_length_tag,
                                                        v_acquirer_institution_code);

    return_status := PCRD_TAG_PROCESSING.GET_TAG    (  PCRD_TAG_PROCESSING.CARD_ACCEPTOR_TERM_ID,
                                                        p_tlv_data,
                                                        v_length_tag,
                                                        v_card_acceptor_term_id);

    return_status := PCRD_TAG_PROCESSING.GET_TAG    (  PCRD_TAG_PROCESSING.CARD_ACCEPTOR_ID,
                                                        p_tlv_data,
                                                        v_length_tag,
                                                        v_card_acceptor_id);
/*Start Ovinno20231222*/
 IF TRIM(v_card_acceptor_id) IS NULL
        THEN

            RETURN_STATUS :=  PCRD_TAG_PROCESSING.GET_TAG (PCRD_TAG_PROCESSING.NETWORK_CODE,
                                          P_TLV_DATA,
                                          V_LEN_TAG,
                                          V_NETWORK_CODE
                                         );

            Return_status := PCRD_TAG_PROCESSING.GET_TAG   (    PCRD_TAG_PROCESSING.card_acc_name_address,
                                                                p_tlv_data ,
                                                                v_len_tag,
                                                                v_field_043);

            IF v_network_code = '02' --MasterCard
            THEN
                v_country_code := SUBSTR(v_field_043, 1, 22);
            ELSIF v_network_code in ('01','04')-- VISA and AMEX
            THEN
                v_country_code := SUBSTR(v_field_043, 1, 25);
            END IF;

        END IF;
/*End Ovinno20231222*/



    v_acq_bank_network_rec.bank_code        := v_card_range_rec.issuing_bank_code;
    v_acq_bank_network_rec.network_code     := NVL(v_acquirer_network_code, v_card_range_rec.network_code);
    v_acq_bank_network_rec.acquirer_id      := v_acquirer_institution_code;
		
    v_acq_bank_network_rec.terminal_id      := v_card_acceptor_term_id;
    v_acq_bank_network_rec.private_data     := v_acq_bank_pvt_data;
    v_acq_bank_network_rec.acq_bank_code    := NULL;

    return_status := PCRD_AUTHO_PARAM_DATA.GET_MER_ACQ_BANK  (  v_acq_bank_network_rec );

    IF return_status = DECLARATION_CST.ERROR
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                    event_global_vars.TLV_ERROR_DATA ,
                                                    'Err Load Get GET_MER_ACQ_BANK : Ins Tag ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

    v_acquirer_bank := NVL(v_acq_bank_network_rec.acq_bank_code,v_acquirer_bank); --ICH20170831

    return_status := PCRD_TAG_PROCESSING.PUT_TAG (      PCRD_TAG_PROCESSING.ACQUIRER_BANK ,
                                                        --NVL(v_acq_bank_network_rec.acq_bank_code,v_acquirer_bank)
                                                        v_acquirer_bank,
                                                        p_tlv_data
                                             );
    IF return_status != DECLARATION_CST.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : Ins Tag ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

/*End ICH20170809*/


    Spy_counter := 40;
    return_status :=    PCRD_TRANS_PARAM_DATA.GET_ORIGINE_CODE (     v_card_range_rec.issuing_bank_code,
                                                                    v_acquirer_bank   ,
                                                                    NULL,
                                                                    NULL,
                                                                    v_origine_code );
    IF return_status != DECLARATION_CST.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                    event_global_vars.INVALID_ISSUER_DATA ,
                                                    'Err Load Iss Data : Ins Tag ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

/*RAM MCB CYCLE 3 Custo*/
    Return_status := PCRD_TAG_PROCESSING.GET_TAG   (    PCRD_TAG_PROCESSING.acquiring_country_code,
                                                        p_tlv_data,
                                                        v_len_tag,
                                                        v_country_code);

        IF TRIM(v_country_code) IS NULL
        THEN

            RETURN_STATUS :=  PCRD_TAG_PROCESSING.GET_TAG (PCRD_TAG_PROCESSING.NETWORK_CODE,
                                          P_TLV_DATA,
                                          V_LEN_TAG,
                                          V_NETWORK_CODE
                                         );

            Return_status := PCRD_TAG_PROCESSING.GET_TAG   (    PCRD_TAG_PROCESSING.card_acc_name_address,
                                                                p_tlv_data ,
                                                                v_len_tag,
                                                                v_field_043);

            IF v_network_code = '02'
            THEN
                v_country_code := SUBSTR(v_field_043, -3);
            ELSIF v_network_code in ('01','04')-- VISA and AMEX
            THEN
                v_country_code := SUBSTR(v_field_043, -2);
            END IF;

        END IF;

        IF v_country_code IN  ('MUS','480','MU') AND v_origine_code = global_vars.ORIGIN_CODE_C_ONUS_M_FOREIGN
        THEN
            v_origine_code := global_vars.ORIGIN_CODE_C_ONUS_M_NATIONAL;
        END IF;
/************/


Spy_counter := 41;
    IF v_origine_code IS NOT NULL
    THEN
       return_status := PCRD_TAG_PROCESSING.PUT_TAG (   PCRD_TAG_PROCESSING.origine_code ,
                                                        v_origine_code  ,
                                                        p_tlv_data
                                                    );
        IF return_status != DECLARATION_CST.OK
        THEN
            PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : Ins Tag ' || Spy_counter);
            RETURN(DECLARATION_CST.NOK);
        END IF;

        --PROD00034664: velocity limits not calculated for cards when not defined in PWC
        IF v_origine_code IN (  GLOBAL_VARS.ORIGIN_CODE_C_ONUS_M_LOCAL,
                                GLOBAL_VARS.ORIGIN_CODE_C_ONUS_M_NATIONAL,
                                GLOBAL_VARS.ORIGIN_CODE_C_ONUS_M_FOREIGN)
        THEN
            return_status := PCRD_TAG_PROCESSING.PUT_TAG (  PCRD_TAG_PROCESSING.card_activity_flag          ,
                                                            'Y'     ,
                                                            p_tlv_data
                                                 );
            IF return_status != DECLARATION_CST.OK
            THEN
                PCRD_P7_GENERAL_TOOLS.put_event(                p_tlv_data,
                                                                event_global_vars.INVALID_ISSUER_DATA ,
                                                                'Err Insert Card Activity Flag Update: ' );
                RETURN(DECLARATION_CST.NOK);
            END IF;
        END IF;
    END IF;

-----------------------------------------------------------------------------------------
Spy_counter := 50;
    IF v_card_product_rec.event_rules_index IS NOT NULL
    THEN
        Return_status := PCRD_TAG_PROCESSING.PUT_PRIVATE_TAG(   PCRD_TAG_PROCESSING.EVENT_RULES_INDEX,
                                                                v_card_product_rec.event_rules_index,
                                                                p_tlv_data);
        IF Return_status <> declaration_cst.OK
        THEN
            PCRD_P7_GENERAL_TOOLS.put_event(p_tlv_data,
                                            event_global_vars.INVALID_ISSUER_DATA ,
                                            'Err Load Iss Data : Ins Tag ' ||PCRD_TAG_PROCESSING.EVENT_RULES_INDEX|| Spy_counter);
            RETURN(DECLARATION_CST.NOK);
        END IF;
    END IF;
-----------------------------------------------------------------------------------------

  ----------------------------------------------------------------------------------------
    -- . ACQUIRER RESOURCE CODE

----------------------------------------------------------------------------------------
    -- . Loading Exception File data if they are not null
----------------------------------------------------------------------------------------
Spy_counter := 42;
      return_status := PCRD_P7_EXCEPTION_FILE_PROC.LOAD_EXCEPTION_DATA   (   p_tlv_data  ,
                                                                             p_card_number
                                                                          );
      IF return_status = DECLARATION_CST.ERROR
      THEN
          RETURN(DECLARATION_CST.NOK);
      END IF;


 ----------------------------------------------------------------------------------------
    -- . Loading Balance Parameters
----------------------------------------------------------------------------------------
Spy_counter := 43;
    --EBE150121: Get control verif flag OFF by default(needed to process advices and to know if we are managing the account
    return_status := PCRD_P7_CTRL_SECURITY.GET_CTRL_VERIF_FLAGS(p_tlv_data,'OFF',v_sec_verif_level,v_cvv2_retry_max,v_exp_date_retry_max);
    IF return_status <> DECLARATION_CST.OK
    THEN
        RETURN(DECLARATION_CST.NOK);
    END IF;

    Return_status := PCRD_TAG_PROCESSING.PUT_PRIVATE_TAG(   PCRD_TAG_PROCESSING.PRIV_ON_OFF_FLAG,
                                                            'OFF',
                                                            p_tlv_data);
    IF Return_status <> declaration_cst.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                    event_global_vars.INVALID_ISSUER_DATA ,
                                                    'Err Load Iss Data : Ins Tag ' ||PCRD_TAG_PROCESSING.PRIV_ON_OFF_FLAG|| Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;


    -- IKR_02032022_Art2.8 START Art2.8
    return_status := pcrd_p7_ctrl_security.ADJUST_SECURITY_FLAGS (p_tlv_data,
                                            v_sec_verif_level);
    IF return_status != DECLARATION_CST.OK
    THEN
        RETURN(DECLARATION_CST.NOK);
    END IF;
    
    -- IKR_02032022_Art2.8 END Art2.8


Spy_counter := 44;
    return_status := PCRD_TAG_PROCESSING.PUT_TAG (   PCRD_TAG_PROCESSING.security_verif_level ,
                                                    v_sec_verif_level  ,
                                                    p_tlv_data
                                                    );
    IF return_status != DECLARATION_CST.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                    event_global_vars.INVALID_ISSUER_DATA ,
                                                    'Err Load Iss Data : Ins Tag ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

    --Start AMER20180405 PROD00055201: Initialize security_verif_result in order to display the default value
    --in authorization screen when this field is not populated (It's the case when an authorization is routed)
    return_status := PCRD_TAG_PROCESSING.PUT_TAG (   PCRD_TAG_PROCESSING.security_verif_result ,
                                                    '4444444444444444444444444R444444'  ,
                                                    p_tlv_data
                                                    );
    IF return_status != DECLARATION_CST.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                    event_global_vars.INVALID_ISSUER_DATA ,
                                                    'Err Load Iss Data : Error on put security_verif_result');
        RETURN(DECLARATION_CST.NOK);
    END IF;
    --End AMER20180405 PROD00055201

Spy_counter := 45;
    return_status := PCRD_TAG_PROCESSING.GET_TAG (   PCRD_TAG_PROCESSING.account_level ,--YDA20170608
                                                    p_tlv_data  ,
                                                    v_length_tag,
                                                    v_account_level
                                                );
    IF return_status != DECLARATION_CST.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                    event_global_vars.TLV_ERROR_DATA ,
                                                    'Err Load Get Data : Ins Tag ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

Spy_counter := 46;
    --EBE160109 IF v_card_rec.card_number IS NOT NULL  --YK27062006 GET_ACCOUNT only of there is a card


    /*RAM 2411 Account selection */
     IF v_card_rec.card_number IS NOT NULL THEN
          return_status := PCRD_P7_ACCOUNT_MNG.GET_ACCOUNT  (   p_tlv_data  );
            IF return_status <> DECLARATION_CST.OK
            THEN
                RETURN(DECLARATION_CST.NOK);
            END IF;
     ENd IF;
    /**/
    IF v_account_level = 'Y'--YDA20170608
    THEN
        return_status := PCRD_P7_ACCOUNT_MNG.GET_ACCOUNT  (   p_tlv_data  );
        IF return_status <> DECLARATION_CST.OK
        THEN
            RETURN(DECLARATION_CST.NOK);
        END IF;
Spy_counter := 47;
        return_status := PCRD_TAG_PROCESSING.GET_TAG (  PCRD_TAG_PROCESSING.SHADOW_ACCOUNT_LEVEL ,
                                                        p_tlv_data  ,
                                                        v_length_tag,
                                                        v_shadow_account_level
                                                    );
        IF return_status != DECLARATION_CST.OK
        THEN
            PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                        event_global_vars.TLV_ERROR_DATA ,
                                                        'Err Load Get Data : Ins Tag ' || Spy_counter);
            RETURN(DECLARATION_CST.NOK);
        END IF;
Spy_counter := 48;
        v_cr_auth_opt := 'N';
        IF SUBSTR(v_processing_code,1,2) IN ('20','21','28')
        THEN
            return_status := PCRD_CARD_PARAM_DATA.GET_CREDIT_AUTH_PARAM  (  v_card_range_rec.issuing_bank_code,
                                                                            v_card_range_rec.services_setup_index,
                                                                            v_credit_auth_param_rec  );
            IF return_status <> DECLARATION_CST.OK
            THEN
                PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                            event_global_vars.TLV_ERROR_DATA ,
                                                            'Err Load Get CR AUTH OPT : Ins Tag ' || v_card_range_rec.issuing_bank_code||','||v_card_range_rec.services_setup_index);
                RETURN(DECLARATION_CST.NOK);
            END IF;

            IF SUBSTR(v_processing_code,1,2) = '20'
            THEN
                v_cr_auth_opt := v_credit_auth_param_rec.refund_opt;
            ELSIF SUBSTR(v_processing_code,1,2) = '21'
            THEN
                v_cr_auth_opt := v_credit_auth_param_rec.deposit_opt;
            ELSIF SUBSTR(v_processing_code,1,2) = '28'
            THEN
                v_cr_auth_opt := v_credit_auth_param_rec.payment_opt;
            END IF;
        END IF;
/*
        IF v_shadow_account_level = 'Y'
        THEN
Spy_counter := 49;
            return_status := PCRD_TAG_PROCESSING.GET_TAG (  PCRD_TAG_PROCESSING.source_account_number ,
                                                            p_tlv_data  ,
                                                            v_length_tag,
                                                            v_shadow_account_nbr
                                                        );
            IF return_status != DECLARATION_CST.OK
            THEN
                PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                            event_global_vars.TLV_ERROR_DATA ,
                                                            'Err Get SH ACC : Ins Tag ' || Spy_counter);
                RETURN(DECLARATION_CST.NOK);
            END IF;

Spy_counter := 69;
        END IF;
*/

    END IF;


    v_card_auth_opt :=  NVL(v_card_range_rec.card_file_option,'N')||
                        NVL(v_cr_auth_opt,'N')--||
                        --NVL(v_vel_chk_opt,'Y')
                        ;


    return_status := PCRD_TAG_PROCESSING.PUT_PRIVATE_TAG (  PCRD_TAG_PROCESSING.priv_iss_auth_opt ,
                                                            v_card_auth_opt  ,
                                                            p_tlv_data
                                                        );
    IF return_status != DECLARATION_CST.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                    event_global_vars.INVALID_ISSUER_DATA ,
                                                    'Err Load Iss Data : Ins Tag ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;

Spy_counter := 87;

    v_is_chip_card := FALSE;
    IF v_card_range_rec.network_code != GLOBAL_VARS.NETWORK_AMEX
    THEN
        IF  SUBSTR(v_card_range_rec.service_code,1,1) IN ('2','6')
        THEN
            v_is_chip_card := TRUE;
        END IF;
    ELSE
        IF ( v_card_range_rec.service_code IN ('201','702')
            OR  SUBSTR(v_card_range_rec.service_code,1,1) IN ('2') /*ABL14122018* Chip Card AMEX */
            )
        THEN
            v_is_chip_card := TRUE;
        END IF;
    END IF;

    -- Load chip card related data
    --IF  SUBSTR(v_card_range_rec.service_code,1,1) IN ('2','6')
    IF v_is_chip_card
--    AND v_card_range_rec.card_file_option = 'Y'         --EBE160107
    AND v_index_application_code IS NOT NULL --PROD00032359
    THEN

        Spy_counter := 750;


        Return_status := PCRD_EMV_PARAM_DATA.GET_ICC_APP_PAR_INDEX (    v_card_range_rec.issuing_bank_code,
                                                                        v_index_application_code,
                                                                        v_icc_app_par_index_rec);
        IF Return_status <> declaration_cst.OK
        THEN
            PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : ICC Appl idx' || Spy_counter);
            RETURN(DECLARATION_CST.NOK);
        END IF;

        Spy_counter := 751;

        Return_status := PCRD_EMV_PARAM_DATA.GET_ICC_APPL_PARAM (   v_card_range_rec.issuing_bank_code,
                                                                    v_index_application_code,
                                                                    v_emv_icc_appl_param_rec);
        IF Return_status <> declaration_cst.OK
        THEN
            PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : ICC Appl ' || Spy_counter);
            RETURN(DECLARATION_CST.NOK);
        END IF;


        v_appl_id           := NVL(v_icc_app_par_index_rec.application_id,v_emv_icc_appl_param_rec.application_type);
        v_iad_fmt           := NULL; --To be mapped
        v_pin_unblk_opt     := EMV_GLOBAL_VARS.PU_ON_CNTR_EXC + EMV_GLOBAL_VARS.PIN_ON_CMD_RECV;
        v_pin_chg_opt       := EMV_GLOBAL_VARS.PC_ON_PIN_UNBLK_CMD + EMV_GLOBAL_VARS.PC_ON_PIN_CHG;
        v_arpc_mthd         := EMV_GLOBAL_VARS.ARPC_MTHD_1;
        v_crd_key_drv_mthd  := EMV_GLOBAL_VARS.ICC_KEY_MTHD_A;
        v_sk_drv_mthd       := EMV_GLOBAL_VARS.SK_MTHD_EMV2000;
        v_ucol              := v_emv_icc_appl_param_rec.upper_consecutive_offlimit;

        BEGIN
            SELECT      COUNT(*)
            INTO        v_count
            FROM        ICC_CARD_VERIFICATION_DETAIL
            WHERE       BANK_CODE               = v_card_range_rec.issuing_bank_code
            AND         ICC_APPLICATION_CODE    = v_index_application_code
            AND         SUBSTR(CVM_CODE_BIT_6_1,-4) = '0001';
            EXCEPTION
                WHEN OTHERS THEN
                    NULL;
        END;
        IF v_count <> 0
        THEN
            v_ofln_pin_opt := '1';
        ELSE
            v_ofln_pin_opt := '0';
        END IF;

        PCRD_P7_SWI_ISS_DATA.BUILD_EMV_CARD_INFO_PARAM  (   v_appl_id                ,
                                                            v_iad_fmt                ,
                                                            v_pin_unblk_opt          ,
                                                            v_pin_chg_opt            ,
                                                            v_arpc_mthd              ,
                                                            v_crd_key_drv_mthd       ,
                                                            v_sk_drv_mthd            ,
                                                            v_ofln_pin_opt           ,
                                                            v_ucol                   ,
                                                            v_emv_card_info_param);



        Spy_counter := 751;
        return_status := PCRD_TAG_PROCESSING.PUT_TAG (   PCRD_TAG_PROCESSING.emv_card_info_param ,
                                                        v_emv_card_info_param  ,
                                                        p_tlv_data
                                                    );
        IF return_status != DECLARATION_CST.OK
        THEN
            PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : Ins Tag ' || Spy_counter);
            RETURN(DECLARATION_CST.NOK);
        END IF;

        return_status := PCRD_TAG_PROCESSING.GET_TAG (  PCRD_TAG_PROCESSING.chip_data ,
                                                        p_tlv_data  ,
                                                        v_length_tag,
                                                        v_tag_value
                                                    );
        IF return_status = declaration_cst.OK
        THEN
            Spy_counter := 752;
            v_chip_iad          :=  PCRD_TAG_PROCESSING.EXTRACT_TLV_FROM_BUFFER ( PCRD_TAG_PROCESSING.chip_issuer_application_data,
                                                                                  v_error,
                                                                                  v_tag_len,
                                                                                  v_tag_value,
                                                                                  v_loc_tlv);
            IF v_error <> declaration_cst.OK
            THEN
                PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                            event_global_vars.INVALID_ISSUER_DATA ,
                                                            'Error extract chip_issuer_application_data ');
                RETURN(DECLARATION_CST.NOK);
            END IF;

            Spy_counter := 753;
            Return_status := PCRD_P7_CTRL_EMV_SECURITY.GET_EMV_CVR_FROM_IAD (   v_card_range_rec.issuing_bank_code,
                                                                                v_chip_iad,
                                                                                v_appl_id,
                                                                                v_cvr);
            IF Return_status <> declaration_cst.OK
            THEN
                PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                            event_global_vars.INVALID_ISSUER_DATA ,
                                                            'Err extract CVR from IAD ' || Spy_counter);
                RETURN(DECLARATION_CST.NOK);
            END IF;
            Spy_counter := 754;

            return_status := PCRD_TAG_PROCESSING.PUT_SUB_TAG (      SUBSTR(PCRD_TAG_PROCESSING.chip_cvr,1,3) ,
                                                                    SUBSTR(PCRD_TAG_PROCESSING.chip_cvr,4,3),
                                                                    v_cvr  ,
                                                                    p_tlv_data
                                                                    );
            IF return_status != DECLARATION_CST.OK
            THEN
                PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                            event_global_vars.INVALID_ISSUER_DATA ,
                                                            'Err put cvr tag :  Tag ' || Spy_counter);
                RETURN(DECLARATION_CST.NOK);
            END IF;
        END IF;
    END IF;



Spy_counter := 43;
    --EBE150129: Load limit currency in tlv, will be needed to processes advice which don't go through check limit
    Return_status := PCRD_LIMITS_PARAM_DATA.GET_P7_LIMITS_SETUP_TOTAL  (        v_card_range_rec.issuing_bank_code,
                                                                                v_card_range_rec.limits_indexes,
                                                                                v_p7_limits_setup_tot_rec,
                                                                                FALSE);
    IF return_status = DECLARATION_CST.OK
    THEN
        return_status := PCRD_TAG_PROCESSING.PUT_PRIVATE_TAG (  PCRD_TAG_PROCESSING.priv_limit_currency ,
                                                                v_p7_limits_setup_tot_rec.currency_code  ,
                                                                p_tlv_data
                                                            );
        IF return_status != DECLARATION_CST.OK
        THEN
            PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Load Iss Data : Ins Tag ' || Spy_counter);
            RETURN(DECLARATION_CST.NOK);
        END IF;
    END IF;
       --JOU20170623
    Spy_counter := 443;
    Return_status := PCRD_SWI_AMC_DATA_ROWS.GET_FRAUD_CTRL_PARAM  (     p_tlv_data,
                                                                        v_fraud_ctrl_param);
    IF Return_status = DECLARATION_CST.ERROR
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                    event_global_vars.INVALID_ISSUER_DATA ,
                                                    'Err Retreive fraud ctrl param ' || Spy_counter);
        RETURN(DECLARATION_CST.NOK);
    END IF;
Spy_counter := 444;
    IF Return_status = DECLARATION_CST.OK
    THEN
        /*
        return_status := PCRD_TAG_PROCESSING.PUT_PRIVATE_TAG (  PCRD_TAG_PROCESSING.priv_frd_ctrl_param ,
                                                                v_fraud_ctrl_param  ,
                                                                p_tlv_data
                                                        );*/
        return_status := PCRD_TAG_PROCESSING.PUT_TAG (   PCRD_TAG_PROCESSING.frd_ctrl_param ,
                                                        v_fraud_ctrl_param  ,
                                                        p_tlv_data
                                                    );
        IF return_status != DECLARATION_CST.OK
        THEN
            PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Err Put fraud ctrl param : Ins Tag ' || Spy_counter);
            RETURN(DECLARATION_CST.NOK);
        END IF;
    END IF;

    --JOU20170623 END
    RETURN(DECLARATION_CST.OK);

EXCEPTION
    WHEN OTHERS THEN
    DECLARE
            v_env_info_trace            global_vars.env_info_trace_type;
    BEGIN
            v_env_info_trace.user_name      :=  global_vars.USER_NAME;
            v_env_info_trace.module_code    :=  global_vars.ML_MISC;
            v_env_info_trace.package_name   :=  $$PLSQL_UNIT;
            v_env_info_trace.function_name  :=  'LOAD_ISSUER_DATA';
            v_env_info_trace.lang           :=  global_vars.LANG;
            v_env_info_trace.user_message   :=  'Error In Function LOAD_ISSUER_DATA';
            PCRD_GENERAL_TOOLS.PUT_TRACES  (v_env_info_trace,Spy_counter );
            PCRD_P7_GENERAL_TOOLS.put_event(p_tlv_data,
                                       event_global_vars.INVALID_ISSUER_DATA ,
                                       'Err Load Iss Data : ERROR See PCARD_TRACE ');
            RETURN(DECLARATION_CST.ERROR);
     END;
END LOAD_ISSUER_DATA;
------------------------------------------------------------------------------------------------
FUNCTION LOAD_SECURITY_CHECKS_PARAMS (   p_tlv_data                  IN OUT NOCOPY   VARCHAR2)
                                    RETURN  PLS_INTEGER IS


Return_Status                       PLS_INTEGER;
v_env_info_trace                    global_vars.env_info_trace_type;
v_length_tag                        PLS_INTEGER;
v_security_verif_level              AUTHO_ACTIVITY_ADM.security_verif_level%TYPE;
v_card_number                       AUTHO_ACTIVITY_ADM.card_number%TYPE;
v_card_range_rec                    CARD_RANGE%ROWTYPE;
--v_card_product_rec                  CARD_PRODUCT%ROWTYPE;
v_hsm_key_member_rec                HSM_KEY_MEMBER%ROWTYPE;
v_emv_keys_assignment_rec           EMV_KEYS_ASSIGNMENT%ROWTYPE;
v_cvk_key                           HSM_KEY_MEMBER.key1_value%TYPE;
v_pvk_key                           HSM_KEY_MEMBER.key1_value%TYPE;
v_ac_key                            HSM_KEY_MEMBER.key1_value%TYPE;
v_smi_key                           HSM_KEY_MEMBER.key1_value%TYPE;
v_smc_key                           HSM_KEY_MEMBER.key1_value%TYPE;
v_dcvv_key                          HSM_KEY_MEMBER.key1_value%TYPE;
v_avv_key                           HSM_KEY_MEMBER.key1_value%TYPE;
v_aid                               VARCHAR2(64);--SNO211215
v_error                             PLS_INTEGER;
v_idx                               PLS_INTEGER;
v_t2_data                           VARCHAR2(256);
v_pin_data                          VARCHAR2(256);
v_pin_info_found                    BOOLEAN := TRUE;
v_pin_change_info_rec               PIN_CHANGE_INFO%ROWTYPE;
v_pvki                              CARD_RANGE.pvki%TYPE;
v_key_set                           CARD_RANGE.key_set_number_1%TYPE;
v_card_sec_info_data                VARCHAR2(128);
v_service_code                      CARD_RANGE.service_code%TYPE;
--v_card_rec                          CARD%ROWTYPE; --MKH08032016 SIB
v_icc_application_index             CARD_PRODUCT.icc_application_index%TYPE;
v_product_code                      CARD_RANGE.product_code%TYPE;
v_issuer_bin                        CARD_RANGE.issuer_bin%TYPE;
v_tag_len                           PLS_INTEGER;
v_tag_value                         VARCHAR2(4096);
v_network_code                      CARD_RANGE.network_code%TYPE;
v_chip_data                         VARCHAR2(1024);
v_dcvv_seq                          v_emv_keys_assignment_rec.mdk_seq%TYPE;--ICH20171006 Get DCVV seq for MCI from card range
v_is_chip_card                      BOOLEAN := FALSE;
BEGIN

    v_env_info_trace.user_name      :=  global_vars.USER_NAME;
    v_env_info_trace.module_code    :=  global_vars.ML_AUTHORIZATION;
    v_env_info_trace.lang           :=  global_vars.LANG;
    v_env_info_trace.package_name   :=  $$PLSQL_UNIT;
    v_env_info_trace.function_name  :=  'LOAD_SECURITY_CHECKS_PARAMS';


    return_status := PCRD_TAG_PROCESSING.GET_TAG (   PCRD_TAG_PROCESSING.card_number ,
                                                    p_tlv_data  ,
                                                    v_length_tag,
                                                    v_card_number
                                                );
    IF return_status != DECLARATION_CST.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(p_tlv_data,
                                       event_global_vars.INVALID_ISSUER_DATA ,
                                       'Err Get card from tlv ');
        RETURN(DECLARATION_CST.NOK);
    END IF;

    return_status := PCRD_TAG_PROCESSING.GET_TAG (   PCRD_TAG_PROCESSING.RECEIVING_INSTITUTION ,
                                                    p_tlv_data  ,
                                                    v_length_tag,
                                                    v_issuer_bin
                                                );
    IF return_status != DECLARATION_CST.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(p_tlv_data,
                                       event_global_vars.INVALID_ISSUER_DATA ,
                                       'Err get issuer bin from tlv ');
        RETURN(DECLARATION_CST.NOK);
    END IF;
    v_product_code  := NULL;--ICH20160420
    return_status := PCRD_TAG_PROCESSING.GET_TAG (   PCRD_TAG_PROCESSING.PRODUCT_CODE ,
                                                    p_tlv_data  ,
                                                    v_length_tag,
                                                    v_product_code
                                               );
 /*    IF return_status != DECLARATION_CST.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(p_tlv_data,
                                       event_global_vars.INVALID_ISSUER_DATA ,
                                       'Err get product code from tlv ');
        RETURN(DECLARATION_CST.NOK);
    END IF;
*/
--Start ICH20160420
    IF return_status = DECLARATION_CST.ERROR
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(p_tlv_data,
                                       event_global_vars.INVALID_ISSUER_DATA ,
                                       'Err get product code from tlv ');
        RETURN(DECLARATION_CST.NOK);
    END IF;
   --End ICH20160420
    return_status := PCRD_TAG_PROCESSING.GET_TAG (   PCRD_TAG_PROCESSING.service_code ,
                                                    p_tlv_data  ,
                                                    v_length_tag,
                                                    v_service_code
                                                );
    IF return_status = DECLARATION_CST.ERROR
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(p_tlv_data,
                                       event_global_vars.INVALID_ISSUER_DATA ,
                                       'Err get service code from tlv ');
        RETURN(DECLARATION_CST.NOK);
    END IF;

    return_status := PCRD_TAG_PROCESSING.GET_TAG (   PCRD_TAG_PROCESSING.network_code ,
                                                    p_tlv_data  ,
                                                    v_length_tag,
                                                    v_network_code
                                                );
    IF return_status = DECLARATION_CST.ERROR
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(p_tlv_data,
                                       event_global_vars.INVALID_ISSUER_DATA ,
                                       'Err get network code from tlv ');
        RETURN(DECLARATION_CST.NOK);
    END IF;


    return_status := PCRD_TAG_PROCESSING.GET_TAG (   PCRD_TAG_PROCESSING.security_verif_level ,
                                                    p_tlv_data  ,
                                                    v_length_tag,
                                                    v_security_verif_level
                                                );
    IF return_status != DECLARATION_CST.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(p_tlv_data,
                                       event_global_vars.INVALID_ISSUER_DATA ,
                                       'Err get security verif level from tlv ');
        RETURN(DECLARATION_CST.NOK);
    END IF;


    Return_Status := PCRD_CARD_PARAM_DATA.GET_CARD_RANGE (  v_card_number,
                                                            v_card_range_rec );
    IF Return_Status <> declaration_cst.OK
    THEN
        v_env_info_trace.user_message := 'ERROR RETURNED BY PCRD_GET_PARAM_CARD_ROWS.GET_CARD_RANGE'
                                      || '. p_card_number=['|| PCRD_TOOLS_MISC_CHECKING.MASKED_CARD_NUMBER(v_card_number)||']'
                                      ;
        PCRD_GENERAL_TOOLS.PUT_TRACES (v_env_info_trace,$$PLSQL_LINE);
        PCRD_P7_GENERAL_TOOLS.put_event(p_tlv_data,
                                       event_global_vars.INVALID_ISSUER_DATA ,
                                       'Err get card range ');
        RETURN Return_Status;
    END IF;

    v_is_chip_card := FALSE;
    IF v_network_code != GLOBAL_VARS.NETWORK_AMEX
    THEN
        IF  SUBSTR(v_service_code,1,1) IN ('2','6')
        THEN
            v_is_chip_card := TRUE;
        END IF;
    ELSE
        IF v_service_code IN ('201','702')
        THEN
            v_is_chip_card := TRUE;
        END IF;
    END IF;


    IF SUBSTR(v_security_verif_level,PCRD_P7_CTRL_SECURITY.SEC_FLAG_CHK_CVV1,1) = 'Y'
    OR SUBSTR(v_security_verif_level,PCRD_P7_CTRL_SECURITY.SEC_FLAG_CHK_CVV2,1) = 'Y'
    OR SUBSTR(v_security_verif_level,PCRD_P7_CTRL_SECURITY.SEC_FLAG_CHK_ICVV,1) = 'Y'
    THEN
        Return_Status := PCRD_GET_PARAM_HSM_ROWS.GET_HSM_KEY_MEMBER_REC  (  v_card_range_rec.issuing_bank_code,
                                                                            'CVKA',
                                                                            v_card_range_rec.primary_cvv_key_number,
                                                                            v_hsm_key_member_rec );

        IF Return_Status <> declaration_cst.OK
        THEN
            v_env_info_trace.user_message := 'ERROR RETURNED BY PCRD_GET_PARAM_CARD_ROWS.GET_HSM_KEY_MEMBER_REC CVKA'   || ' ' ||
                                             'BANK CODE : '     || v_card_range_rec.issuing_bank_code                   || ' ' ||
                                             'SEQ NUMBER : '    || v_card_range_rec.primary_cvv_key_number;
            PCRD_GENERAL_TOOLS.PUT_TRACES (v_env_info_trace,$$PLSQL_LINE);
            PCRD_P7_GENERAL_TOOLS.put_event(p_tlv_data,
                                       event_global_vars.INVALID_ISSUER_DATA ,
                                       'Err get CVKA Keys ');
            RETURN Return_Status;
        END IF;

        v_cvk_key := v_hsm_key_member_rec.key1_value;

        Return_Status := PCRD_GET_PARAM_HSM_ROWS.GET_HSM_KEY_MEMBER_REC  (  v_card_range_rec.issuing_bank_code,
                                                                            'CVKB',
                                                                            v_card_range_rec.primary_cvv_key_number,
                                                                            v_hsm_key_member_rec );

        IF Return_Status <> declaration_cst.OK
        THEN
            v_env_info_trace.user_message := 'ERROR RETURNED BY PCRD_GET_PARAM_CARD_ROWS.GET_HSM_KEY_MEMBER_REC CVKB'   || ' ' ||
                                             'BANK CODE : '     || v_card_range_rec.issuing_bank_code                   || ' ' ||
                                             'SEQ NUMBER : '    || v_card_range_rec.primary_cvv_key_number;
            PCRD_GENERAL_TOOLS.PUT_TRACES (v_env_info_trace,$$PLSQL_LINE);
            PCRD_P7_GENERAL_TOOLS.put_event(p_tlv_data,
                                       event_global_vars.INVALID_ISSUER_DATA ,
                                       'Err get CVKB Keys ');
            RETURN Return_Status;
        END IF;

        v_cvk_key := v_cvk_key || v_hsm_key_member_rec.key1_value;

        return_status := PCRD_TAG_PROCESSING.PUT_TAG (   PCRD_TAG_PROCESSING.cvk ,
                                                        v_cvk_key,
                                                        p_tlv_data
                                                  );
        IF return_status != DECLARATION_CST.OK
        THEN
            PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Error Put Tag CVK ');
            RETURN(DECLARATION_CST.NOK);
        END IF;
    END IF;


    return_status := PCRD_TAG_PROCESSING.GET_TAG (  PCRD_TAG_PROCESSING.pin_data ,
                                                    p_tlv_data  ,
                                                    v_length_tag,
                                                    v_pin_data);

    /*SDH10022020_Start Pin selection case*/
    IF return_status <> Declaration_cst.OK
    THEN
        return_status := PCRD_TAG_PROCESSING.GET_TAG (  PCRD_TAG_PROCESSING.acquirer_reference_data ,
                                                        p_tlv_data  ,
                                                        v_length_tag,
                                                        v_pin_data);
    END IF;
    /*SDH10022020_End*/

    IF  SUBSTR(v_security_verif_level,PCRD_P7_CTRL_SECURITY.SEC_FLAG_CHK_PIN,1) = 'Y'
    AND return_status = Declaration_cst.OK /*SDH condition a verifier pour le pin selection*/
    THEN


        v_pin_info_found := TRUE;
        BEGIN
            SELECT *
            INTO   v_pin_change_info_rec
            FROM   PIN_CHANGE_INFO
            WHERE  card_number = v_card_number;

        EXCEPTION
        WHEN OTHERS THEN
            v_pin_info_found := FALSE;
        END;

        IF SUBSTR(v_security_verif_level,PCRD_P7_CTRL_SECURITY.SEC_FLAG_PIN_MTHD,1) = PCRD_P7_CTRL_SECURITY.PIN_MTHD_PVV
        THEN
            IF v_pin_info_found
            THEN
                v_pvki := v_pin_change_info_rec.pvki;
            END IF;

            IF v_network_code != GLOBAL_VARS.NETWORK_AMEX
            THEN
                IF  NOT v_pin_info_found
                OR  v_pvki IS NULL
                THEN
                    return_status := PCRD_TAG_PROCESSING.GET_TAG (   PCRD_TAG_PROCESSING.TRACK2_DATA ,
                                                                    p_tlv_data  ,
                                                                    v_length_tag,
                                                                    v_t2_data
                                                                );
                    IF return_status != DECLARATION_CST.OK
                    THEN
                            PCRD_P7_GENERAL_TOOLS.put_event(p_tlv_data,
                                           event_global_vars.INVALID_ISSUER_DATA ,
                                           'Err get Track2 from tlv');
                            RETURN(DECLARATION_CST.NOK);
                    END IF;

                    FOR v_i IN 1..LENGTH(v_t2_data)
                    LOOP
                        IF NOT SUBSTR(v_t2_data,v_i,1) BETWEEN '0' AND '9'
                        THEN
                            v_idx := v_i;
                            EXIT;
                        END IF;
                    END LOOP;
                    IF v_idx + 1 + 4 + 3 < LENGTH(v_t2_data)
                    THEN
                        v_pvki := SUBSTR(v_t2_data, v_idx + 1 + 4 + 3, 1);
                    END IF;

                END IF;

                IF      v_pvki = 1      THEN    v_key_set := v_card_range_rec.key_set_number_1;
                ELSIF   v_pvki = 2      THEN    v_key_set := v_card_range_rec.key_set_number_2;
                ELSIF   v_pvki = 3      THEN    v_key_set := v_card_range_rec.key_set_number_3;
                ELSIF   v_pvki = 4      THEN    v_key_set := v_card_range_rec.key_set_number_4;
                ELSIF   v_pvki = 5      THEN    v_key_set := v_card_range_rec.key_set_number_5;
                ELSIF   v_pvki = 6      THEN    v_key_set := v_card_range_rec.key_set_number_6;
                ELSE
                    v_env_info_trace.user_message   :=  v_pvki || ' : pvki non reconu ';
                    PCRD_GENERAL_TOOLS.PUT_TRACES  (v_env_info_trace,$$PLSQL_LINE );
                    PCRD_P7_GENERAL_TOOLS.put_event(p_tlv_data,
                                           event_global_vars.INVALID_ISSUER_DATA ,
                                           'Invalid PVKI['||v_pvki||']');
                    RETURN declaration_cst.ERROR;
                END IF;
            ELSE
                --Default to 1.
                v_key_set := v_card_range_rec.key_set_number_1;
            END IF;
        ELSE
            v_key_set := v_card_range_rec.key_set_number_1;
        END IF;

        Return_Status := PCRD_GET_PARAM_HSM_ROWS.GET_HSM_KEY_MEMBER_REC  (  v_card_range_rec.issuing_bank_code,
                                                                            'PVKA',
                                                                            v_key_set,
                                                                            v_hsm_key_member_rec );

        IF Return_Status <> declaration_cst.OK
        THEN
            v_env_info_trace.user_message := 'ERROR RETURNED BY PCRD_GET_PARAM_CARD_ROWS.GET_HSM_KEY_MEMBER_REC PVKA'   || ' ' ||
                                             'BANK CODE : '     || v_card_range_rec.issuing_bank_code                   || ' ' ||
                                             'SEQ NUMBER : '    || v_key_set;
            PCRD_GENERAL_TOOLS.PUT_TRACES (v_env_info_trace,$$PLSQL_LINE);
            PCRD_P7_GENERAL_TOOLS.put_event(p_tlv_data,
                                       event_global_vars.INVALID_ISSUER_DATA ,
                                       'Error get PVKA');
            RETURN Return_Status;
        END IF;

        v_pvk_key  :=v_hsm_key_member_rec.key1_value;

        Return_Status := PCRD_GET_PARAM_HSM_ROWS.GET_HSM_KEY_MEMBER_REC  (  v_card_range_rec.issuing_bank_code,
                                                                            'PVKB',
                                                                            v_key_set,
                                                                            v_hsm_key_member_rec );

        IF Return_Status <> declaration_cst.OK
        THEN
            v_env_info_trace.user_message := 'ERROR RETURNED BY PCRD_GET_PARAM_CARD_ROWS.GET_HSM_KEY_MEMBER_REC PVKB'   || ' ' ||
                                             'BANK CODE : '     || v_card_range_rec.issuing_bank_code                   || ' ' ||
                                             'SEQ NUMBER : '    || v_key_set;
            PCRD_GENERAL_TOOLS.PUT_TRACES (v_env_info_trace,$$PLSQL_LINE);
            PCRD_P7_GENERAL_TOOLS.put_event(p_tlv_data,
                                       event_global_vars.INVALID_ISSUER_DATA ,
                                       'Error get PVKB');
            RETURN Return_Status;
        END IF;
        v_pvk_key  := v_pvk_key || v_hsm_key_member_rec.key1_value;

        return_status := PCRD_TAG_PROCESSING.PUT_TAG (   PCRD_TAG_PROCESSING.pvk ,
                                                        v_pvk_key,
                                                        p_tlv_data
                                                  );
        IF return_status != DECLARATION_CST.OK
        THEN
            PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Error Put Tag PVK ');
            RETURN(DECLARATION_CST.NOK);
        END IF;

    END IF;

    -- add test on v_card_product_rec.icc_application_index
    -- and on FLD 55 present
    --IF SUBSTR(v_service_code,1,1) IN ('2','6')
    IF v_is_chip_card
    THEN


        return_status := PCRD_TAG_PROCESSING.GET_TAG (   PCRD_TAG_PROCESSING.ICC_APPLICATION_INDX ,
                                                        p_tlv_data  ,
                                                        v_length_tag,
                                                        v_icc_application_index
                                                    );
        IF return_status != DECLARATION_CST.OK
        THEN
            v_icc_application_index := NULL;
        END IF;


        -- Start  SNO211215

       --Start  ICH20170913
        return_status := PCRD_TAG_PROCESSING.GET_TAG (   PCRD_TAG_PROCESSING.chip_data ,
                                                        p_tlv_data  ,
                                                        v_length_tag,
                                                        v_chip_data
                                                    );

        IF return_status = DECLARATION_CST.OK
        THEN
            v_chip_data := TO_CHAR(LENGTH(v_chip_data),'FM0000')||v_chip_data;

            return_status := PCRD_TAG_PROCESSING.GET_TAG (   SUBSTR(PCRD_TAG_PROCESSING.chip_application_identifier,4),
                                                            v_chip_data  ,
                                                            v_length_tag,
                                                            v_aid );
            IF return_status = declaration_cst.OK AND v_aid  IS NOT NULL
            THEN
                    Return_Status := PCRD_EMV_PARAM_DATA.GET_EMV_MULTI_APP_CR_PARAM          (  v_card_range_rec.issuing_bank_code,
                                                                                                v_card_number,
                                                                                                v_aid ,
                                                                                                v_icc_application_index);

                    IF Return_Status = declaration_cst.ERROR
                    THEN
                    v_env_info_trace.user_message := 'ERROR RETURNED PCRD_EMV_PARAM_DATA.GET_EMV_MULTI_APP_CR_PARAM';
                    PCRD_GENERAL_TOOLS.PUT_TRACES (v_env_info_trace,$$PLSQL_LINE);
                   -- RETURN Return_Status;
                    END IF;
            END IF;

        END IF;
       --End  ICH20170913

        /*v_aid          :=  PCRD_TAG_PROCESSING.EXTRACT_TLV_FROM_BUFFER ( PCRD_TAG_PROCESSING.chip_application_identifier,
                                                                          v_error,
                                                                          v_tag_len,
                                                                          v_tag_value,
                                                                          p_tlv_data);--SNO211215
        IF v_error <> declaration_cst.OK
        THEN
            PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                        event_global_vars.INVALID_ISSUER_DATA ,
                                                        'Error extract chip_application_identifier ');
            --RETURN(DECLARATION_CST.NOK);
        END IF;
        IF  v_aid  IS NOT NULL
        THEN
            Return_Status := PCRD_EMV_PARAM_DATA.GET_EMV_MULTI_APP_CR_PARAM          (  v_card_range_rec.issuing_bank_code,
                                                   v_card_number,
                                                   v_aid ,
                                                   v_icc_application_index
                                                );
            IF Return_Status <> declaration_cst.OK
            THEN
            v_env_info_trace.user_message := 'ERROR RETURNED PCRD_EMV_PARAM_DATA.GET_EMV_MULTI_APP_CR_PARAM';
            PCRD_GENERAL_TOOLS.PUT_TRACES (v_env_info_trace,$$PLSQL_LINE);
           -- RETURN Return_Status;
            END IF;
        END IF;*/
        -- End  SNO211215


       /* v_env_info_trace.user_message := 'BEFOR BY PCRD_EMV_PARAM_DATA.GET_EMV_KEYS_ASSIGNMENT'
                                          || '. issuing_bank_code=['||v_card_range_rec.issuing_bank_code||']'
                                          || '. v_card_number=['||PCRD_TOOLS_MISC_CHECKING.MASKED_CARD_NUMBER(v_card_number)||']'
                                          || '. issuer_bin=['||v_issuer_bin||']'
                                          || '. product_code=['||v_product_code||']'
                                          || '. icc_application_index=['||v_icc_application_index||']'
                                          ;
            PCRD_GENERAL_TOOLS.PUT_TRACES (v_env_info_trace,$$PLSQL_LINE);*//*HIRA20201015: Reduce Extra Trace*/

        Return_Status := PCRD_EMV_PARAM_DATA.GET_EMV_KEYS_ASSIGNMENT (  v_card_range_rec.issuing_bank_code,
                                                                        v_card_number,
                                                                        --v_card_range_rec.issuer_bin,
                                                                        --v_card_range_rec.product_code,
                                                                        --v_card_product_rec.icc_application_index,
                                                                        v_issuer_bin,
                                                                        v_product_code,
                                                                        v_icc_application_index,
                                                                        v_emv_keys_assignment_rec );
        IF Return_Status = declaration_cst.ERROR
        THEN
            v_env_info_trace.user_message := 'ERROR RETURNED BY PCRD_EMV_PARAM_DATA.GET_EMV_KEYS_ASSIGNMENT'
                                          || '. issuing_bank_code=['||v_card_range_rec.issuing_bank_code||']'
                                          || '. v_card_number=['||PCRD_TOOLS_MISC_CHECKING.MASKED_CARD_NUMBER(v_card_number)||']'
                                          || '. issuer_bin=['||v_issuer_bin||']'
                                          || '. product_code=['||v_product_code||']'
                                          || '. icc_application_index=['||v_icc_application_index||']'
                                          ;
            PCRD_GENERAL_TOOLS.PUT_TRACES (v_env_info_trace,$$PLSQL_LINE);
           -- RETURN Return_Status;
        END IF;

        IF SUBSTR(v_security_verif_level,PCRD_P7_CTRL_SECURITY.SEC_FLAG_CHK_ARQC,1) = 'Y' AND NVL(v_emv_keys_assignment_rec.mdk_seq, 'X') != 'X'
        THEN
        -- Getting the AC Key from HSM_KEY_MEMBER
            Return_Status := PCRD_GET_PARAM_HSM_ROWS.GET_HSM_KEY_MEMBER_REC  (  v_card_range_rec.issuing_bank_code,
                                                                                'AC',
                                                                                v_emv_keys_assignment_rec.mdk_seq,
                                                                                v_hsm_key_member_rec );

            IF Return_Status <> declaration_cst.OK
            THEN
                v_env_info_trace.user_message := 'ERROR RETURNED BY PCRD_GET_PARAM_CARD_ROWS.GET_HSM_KEY_MEMBER_REC AC'   || ' ' ||
                                                 'BANK CODE : '     || v_card_range_rec.issuing_bank_code                 || ' ' ||
                                                 'SEQ NUMBER : '    || v_emv_keys_assignment_rec.mdk_seq                  || ' ' ||
                                                 'key_code : '      || 'AC';
                PCRD_GENERAL_TOOLS.PUT_TRACES (v_env_info_trace,$$PLSQL_LINE);
                PCRD_P7_GENERAL_TOOLS.put_event(p_tlv_data,
                                       event_global_vars.INVALID_ISSUER_DATA ,
                                       'Error get AC Keys');
                RETURN Return_Status;
            END IF;

            v_ac_key := v_hsm_key_member_rec.key1_value;
            return_status := PCRD_TAG_PROCESSING.PUT_TAG (   PCRD_TAG_PROCESSING.EMV_AC_KEY ,
                                                            v_ac_key,
                                                            p_tlv_data
                                                      );
            IF return_status != DECLARATION_CST.OK
            THEN
                PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                            event_global_vars.INVALID_ISSUER_DATA ,
                                                            'Error Put Tag EMV AC ');
                RETURN(DECLARATION_CST.NOK);
            END IF;
        END IF;

        IF NVL(v_emv_keys_assignment_rec.enc_seq, 'X') != 'X'
        THEN
            Return_Status := PCRD_GET_PARAM_HSM_ROWS.GET_HSM_KEY_MEMBER_REC  (  v_card_range_rec.issuing_bank_code,
                                                                                'SMC',
                                                                                v_emv_keys_assignment_rec.enc_seq,
                                                                                v_hsm_key_member_rec );

            IF Return_Status <> declaration_cst.OK
            THEN
                v_env_info_trace.user_message := 'ERROR RETURNED BY PCRD_GET_PARAM_CARD_ROWS.GET_HSM_KEY_MEMBER_REC AC'   || ' ' ||
                                                 'BANK CODE : '     || v_card_range_rec.issuing_bank_code                   || ' ' ||
                                                 'SEQ NUMBER : '    || v_emv_keys_assignment_rec.enc_seq || ' ' ||
                                                 'key_code : '    || 'SMC';
                PCRD_GENERAL_TOOLS.PUT_TRACES (v_env_info_trace,$$PLSQL_LINE);
                PCRD_P7_GENERAL_TOOLS.put_event(p_tlv_data,
                                       event_global_vars.INVALID_ISSUER_DATA ,
                                       'Error get SMC Key');
                RETURN Return_Status;
            END IF;


            v_smc_key := v_hsm_key_member_rec.key1_value;
            Return_Status := PCRD_GET_PARAM_HSM_ROWS.GET_HSM_KEY_MEMBER_REC  (  v_card_range_rec.issuing_bank_code,
                                                                                'SMI',
                                                                                v_emv_keys_assignment_rec.mac_seq,
                                                                                v_hsm_key_member_rec );

            IF Return_Status <> declaration_cst.OK
            THEN
                v_env_info_trace.user_message := 'ERROR RETURNED BY PCRD_GET_PARAM_CARD_ROWS.GET_HSM_KEY_MEMBER_REC AC'   || ' ' ||
                                                 'BANK CODE : '     || v_card_range_rec.issuing_bank_code                   || ' ' ||
                                                 'SEQ NUMBER : '    || v_emv_keys_assignment_rec.mac_seq || ' ' ||
                                                 'key_code : '    || 'SMI';
                PCRD_GENERAL_TOOLS.PUT_TRACES (v_env_info_trace,$$PLSQL_LINE);
                PCRD_P7_GENERAL_TOOLS.put_event(p_tlv_data,
                                       event_global_vars.INVALID_ISSUER_DATA ,
                                       'Error get SMI Key');
                RETURN Return_Status;
            END IF;


            v_smi_key := v_hsm_key_member_rec.key1_value;
            return_status := PCRD_TAG_PROCESSING.PUT_TAG (   PCRD_TAG_PROCESSING.EMV_SMC_KEY ,
                                                            v_smc_key,
                                                            p_tlv_data
                                                        );
            IF return_status != DECLARATION_CST.OK
            THEN
                PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                            event_global_vars.INVALID_ISSUER_DATA ,
                                                            'Error Put Tag EMV SMC ');
                RETURN(DECLARATION_CST.NOK);
            END IF;

            return_status := PCRD_TAG_PROCESSING.PUT_TAG (   PCRD_TAG_PROCESSING.EMV_SMI_KEY ,
                                                            v_smi_key ,
                                                            p_tlv_data
                                                        );
            IF return_status != DECLARATION_CST.OK
            THEN
                PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                            event_global_vars.INVALID_ISSUER_DATA ,
                                                            'Error Put Tag EMV SMI ');
                RETURN(DECLARATION_CST.NOK);
            END IF;
        END IF;

        IF SUBSTR(v_security_verif_level,PCRD_P7_CTRL_SECURITY.SEC_FLAG_CHK_CVC3,1) = 'Y'
        THEN
        -- Getting the AC Key from HSM_KEY_MEMBER
        --MCI card_range

        --ICH20171006 Get DCVV seq for MCI from card range
            v_dcvv_seq  := v_emv_keys_assignment_rec.mdk_seq;

            IF v_network_code = '02'--MCI
            THEN
                v_dcvv_seq  := v_card_range_rec.dcvv_cvc3_seq_num;
            END IF;
            Return_Status := PCRD_GET_PARAM_HSM_ROWS.GET_HSM_KEY_MEMBER_REC  (  v_card_range_rec.issuing_bank_code,
                                                                                'DCVV',
                                                                                v_dcvv_seq,--v_emv_keys_assignment_rec.mdk_seq,
                                                                                v_hsm_key_member_rec );

            IF Return_Status <> declaration_cst.OK
            THEN
                v_env_info_trace.user_message := 'ERROR RETURNED BY PCRD_GET_PARAM_CARD_ROWS.GET_HSM_KEY_MEMBER_REC AC'   || ' ' ||
                                                 'BANK CODE : '     || v_card_range_rec.issuing_bank_code                   || ' ' ||
                                                 'SEQ NUMBER : '    || v_emv_keys_assignment_rec.mdk_seq || ' ' ||
                                                 'key_code : '    || 'DCVV';
                PCRD_GENERAL_TOOLS.PUT_TRACES (v_env_info_trace,$$PLSQL_LINE);
                PCRD_P7_GENERAL_TOOLS.put_event(p_tlv_data,
                                           event_global_vars.INVALID_ISSUER_DATA ,
                                           'Error get DCVV Key');
                RETURN Return_Status;
            END IF;

            v_dcvv_key := v_hsm_key_member_rec.key1_value;
            return_status := PCRD_TAG_PROCESSING.PUT_TAG (   PCRD_TAG_PROCESSING.DCVV_KEY ,
                                                            v_dcvv_key,
                                                            p_tlv_data
                                                      );
            IF return_status != DECLARATION_CST.OK
            THEN
                PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                            event_global_vars.INVALID_ISSUER_DATA ,
                                                            'Error Put Tag EMV DCVV ');
                RETURN(DECLARATION_CST.NOK);
            END IF;
        END IF;

    END IF;



    IF SUBSTR(v_security_verif_level,PCRD_P7_CTRL_SECURITY.SEC_FLAG_CHK_AAV,1) = 'Y'
    THEN
        NULL; --TODO
    END IF;
/*
    DECLARE
            v_env_info_trace            global_vars.env_info_trace_type;
    BEGIN
    v_env_info_trace.user_message   :=  ' Start['||v_card_range_rec.pin_length||','||v_pvki||','||v_pin_change_info_rec.offset_visa||','||v_pin_change_info_rec.offset;
    PCRD_GENERAL_TOOLS.PUT_TRACES  (v_env_info_trace,$$PLSQL_LINE );

    END;
    */

    PCRD_P7_SWI_ISS_DATA.BUILD_CARD_SEC_INFO_DATA( v_card_range_rec.pin_length,
                                                    v_pvki,
                                                    v_pin_change_info_rec.field1,
                                                    v_pin_change_info_rec.offset,
                                                    v_card_sec_info_data);


    return_status := PCRD_TAG_PROCESSING.PUT_TAG (   PCRD_TAG_PROCESSING.CARD_SEC_INFO_DATA ,
                                                    v_card_sec_info_data,
                                                    p_tlv_data
                                              );
    IF return_status != DECLARATION_CST.OK
    THEN
        PCRD_P7_GENERAL_TOOLS.put_event(            p_tlv_data,
                                                    event_global_vars.INVALID_ISSUER_DATA ,
                                                    'Error Put Tag CARD SEC DATA ');
        RETURN(DECLARATION_CST.NOK);
    END IF;

    RETURN(DECLARATION_CST.OK);

EXCEPTION
    WHEN OTHERS THEN
    DECLARE
            v_env_info_trace            global_vars.env_info_trace_type;
    BEGIN
            v_env_info_trace.user_name      :=  global_vars.USER_NAME;
            v_env_info_trace.module_code    :=  global_vars.ML_MISC;
            v_env_info_trace.package_name   :=  $$PLSQL_UNIT;
            v_env_info_trace.function_name  :=  'LOAD_SECURITY_CHECKS_PARAMS';
            v_env_info_trace.lang           :=  global_vars.LANG;
            v_env_info_trace.user_message   :=  'Error In Function LOAD_SECURITY_CHECKS_PARAMS';
            PCRD_GENERAL_TOOLS.PUT_TRACES  (v_env_info_trace,$$PLSQL_LINE );
            PCRD_P7_GENERAL_TOOLS.put_event(p_tlv_data,
                                       event_global_vars.INVALID_ISSUER_DATA ,
                                       'Err Load Iss Data : ERROR See PCARD_TRACE ');
            RETURN(DECLARATION_CST.ERROR);
     END;
END LOAD_SECURITY_CHECKS_PARAMS;
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
/*START:ZKO16092018*/

-- Name         :   GET_INFO_CARD
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
FUNCTION GET_INFO_CARD(     p_card_number                   IN                  AUTHO_ACTIVITY_ADM.card_number%TYPE,
                            p_network                       IN                  AUTHO_ACTIVITY_ADM.network_code%TYPE,
                            RCardInfo                       OUT NOCOPY          rInfoCardRecord
                        ) RETURN PLS_INTEGER IS

return_status           PLS_INTEGER;
v_env_info_trace                GLOBAL_VARS.ENV_INFO_TRACE_TYPE;
v_card_range_record             card_range%ROWTYPE;
v_dcc_visa_bin_record           DCC_VISA_BIN%ROWTYPE;
v_visa_ardef_record             VISA_ARDEF%ROWTYPE;
v_visa_bin_record               VISA_BIN%ROWTYPE;
v_visa_plus_record              VISA_PLUS%ROWTYPE;


v_mci_mpe_ica_bin_record        MCI_MPE_ICA_BIN%ROWTYPE;
v_mds_fit_rec                   MDS_FIT%ROWTYPE;
v_country_rec                   COUNTRY%ROWTYPE;
v_cup_bin_record                CUP_BIN%ROWTYPE;
v_product_id                    VARCHAR2(10);
v_country                       VARCHAR2(3) := NULL;

BEGIN

    v_env_info_trace.user_name      :=  GLOBAL_VARS.USER_NAME;
    v_env_info_trace.module_code    :=  GLOBAL_VARS.ML_MISC;
    v_env_info_trace.package_name   :=  $$PLSQL_UNIT;
    v_env_info_trace.function_name  :=  'GET_INFO_CARD';
    v_env_info_trace.lang           :=  GLOBAL_VARS.LANG;



    ---ZKO:cette condition ÿ  revoir
    Return_Status   :=  PCRD_CARD_PARAM_DATA.GET_CARD_RANGE      (  p_card_number,
                                                                    v_card_range_record );

    IF  Return_Status   =   declaration_cst.OK  AND  (v_card_range_record.currency_code='480' or v_card_range_record.ISSUING_BANK_CODE ='000001')   -- Carte locale DCC NOT ALLOWED --ARB OLB 13022015
    THEN

           RETURN(declaration_cst.NOK);
    END IF;



    IF   p_network = global_vars.NETWORK_VISA
    THEN
        V_DCC_VISA_BIN_RECORD:=NULL;

        Return_Status:=  PCRD_P7_ROUTING_DATA.GET_DCC_VISA_BIN(p_card_number,
                                                               v_dcc_visa_bin_record);

        IF  Return_Status   =  declaration_cst.OK AND v_dcc_visa_bin_record.bill_currency IS NOT NULL
        THEN
            RCardInfo.CardCurrency := v_dcc_visa_bin_record.bill_currency;
            v_product_id:= NULL;/*TODO*/
            RCardInfo.AccountSource:= NULL; /*TODO*/
            RCardInfo.CountryCode:= NULL;/*TODO*/
            RCardInfo.IssuerBin:= v_dcc_visa_bin_record.issuer_bin;
        ELSE--card not in DCC_VISA_BIN

            Return_Status := PCRD_P7_ROUTING_DATA.GET_VISA_ARDEF    (   p_card_number,
                                                   v_visa_ardef_record
                                                   );

            IF  Return_Status != DECLARATION_CST.OK
            THEN


                Return_Status := PCRD_P7_ROUTING_DATA.GET_VISA_BIN
                                           ( p_card_number,
                                             v_visa_bin_record
                                           );

                IF Return_Status != DECLARATION_CST.OK
                THEN

                    Return_Status := PCRD_P7_ROUTING_DATA.GET_VISA_PLUS
                                           ( p_card_number,
                                             v_visa_plus_record
                                           );


                    IF  Return_Status   != declaration_cst.OK
                    THEN
                            v_env_info_trace.user_message   :=  'Card not exist in VISA tables; card number='||p_card_number;
                            PCRD_GENERAL_TOOLS.PUT_TRACES  (    v_env_info_trace,   200 );
                            RETURN(declaration_cst.NOK);
                    ELSE---card not in VISA_PLUS

                        RCardInfo.AccountSource := NULL;/*TODO*/
                        RCardInfo.IssuerBin :=  v_visa_plus_record.bin;
                        v_product_id :=  NULL;/*TODO*/
                        v_country := NULL;/*TODO*/

                    END IF;


                ELSE ---card not in VISA_BIN


                    RCardInfo.AccountSource := NULL;/*TODO*/
                    RCardInfo.IssuerBin := v_visa_bin_record.bin;
                    v_product_id := NULL;/*TODO*/
                    v_country := TRIM(v_visa_bin_record.country);


                END IF;


            ELSE---card not in visa_ardef

                RCardInfo.AccountSource := v_visa_ardef_record.account_founding_source;
                RCardInfo.IssuerBin := v_visa_ardef_record.issuer_bin;
                v_product_id := v_visa_ardef_record.product_id;
                v_country := TRIM(v_visa_ardef_record.country);



            END IF;


            Return_Status := PCRD_GENERAL_TOOLS_5.GET_COUNTRY_VISA (v_country,
                                              v_country_rec);

            IF  Return_Status   !=  declaration_cst.OK
            THEN
                v_env_info_trace.user_message :=  ' GET_COUNTRY_VISA : ' ||  v_country;
                PCRD_GENERAL_TOOLS.PUT_TRACES  (    v_env_info_trace,   1700 );
                RETURN(declaration_cst.NOK);
            END IF;

            RCardInfo.CardCurrency := v_country_rec.currency_code;
            RCardInfo.CountryCode := v_country_rec.country_code;


        END IF;



    ELSIF   p_network = global_vars.NETWORK_MASTERCARD
    THEN
            Return_Status := PCRD_P7_ROUTING_DATA.GET_MCI_MPE_ICA_BIN   (   p_card_number,
                                                       v_mci_mpe_ica_bin_record
                                                       );

             IF  Return_Status   !=  declaration_cst.OK
             THEN
                    Return_Status   :=  PCRD_P7_ROUTING_DATA.GET_MDS_FIT ( p_card_number,
                                                                        v_mds_fit_rec,
                                                                        TRUE);
                    IF  Return_Status   != declaration_cst.OK
                    THEN
                            v_env_info_trace.user_message   :=  'ERROR RETURNED BY GET_MDS_FIT ni MCI_MPE_ICA_BIN; card numbe='||p_card_number;
                            PCRD_GENERAL_TOOLS.PUT_TRACES  (    v_env_info_trace,   200 );
                            RETURN(declaration_cst.NOK);
                    ELSE
                            Return_Status := PCRD_GET_PARAM_GENERAL_ROWS.GET_COUNTRY  ( v_mds_fit_rec.country_code,
                                                                                        v_country_rec,
                                                                                        TRUE);
                            IF  Return_Status   !=  declaration_cst.OK
                            THEN
                                    v_env_info_trace.user_message :=  ' PCRD_SWI_SERVICES_1.GET_COUNTRY_VISA : ' ||  v_visa_ardef_record.country;
                                    PCRD_GENERAL_TOOLS.PUT_TRACES  (    v_env_info_trace,   1700 );
                                    RETURN(declaration_cst.NOK);
                            END IF;

                            RCardInfo.CardCurrency :=NVL(v_card_range_record.currency_code,v_country_rec.currency_code); --ARB OLB 13022015
                            v_product_id:= NULL;/*TODO*/
                            RCardInfo.AccountSource:= NULL; /*TODO*/
                            RCardInfo.CountryCode:= v_mds_fit_rec.country_code;
                            RCardInfo.IssuerBin:= v_mds_fit_rec.bin;
                    END IF;
             ELSE
                RCardInfo.CardCurrency := v_mci_mpe_ica_bin_record.card_bill_currency;
                v_product_id:= v_mci_mpe_ica_bin_record.card_program_id;
                RCardInfo.AccountSource:= NULL; /*TODO*/
                RCardInfo.CountryCode:= v_mci_mpe_ica_bin_record.numer_country_code;
                RCardInfo.IssuerBin:= v_mci_mpe_ica_bin_record.ica;
             END IF;



    ELSIF    p_network = global_vars.NETWORK_CUP
    THEN
             Return_Status := PCRD_P7_ROUTING_DATA.GET_CUP_BIN_REC   (   p_card_number,
                                                                           v_cup_bin_record
                                                                       );

             IF  Return_Status   !=  declaration_cst.OK
             THEN
                    v_env_info_trace.user_message :=  ' NO BIN RANGE FOUND IN CUP_BIN FOR CARD : ' || p_card_number;
                    PCRD_GENERAL_TOOLS.PUT_TRACES  (    v_env_info_trace,   1900 );
                    RETURN(declaration_cst.NOK);
             END IF;


            Return_Status := PCRD_GENERAL_TOOLS_5.GET_COUNTRY_VISA (v_cup_bin_record.country,
                                              v_country_rec);

            IF  Return_Status   !=  declaration_cst.OK
            THEN
                v_env_info_trace.user_message :=  ' GET_COUNTRY_VISA : ' ||  v_country || ', p_network :' ||p_network;
                PCRD_GENERAL_TOOLS.PUT_TRACES  (    v_env_info_trace,   1700 );
                RETURN(declaration_cst.NOK);
            END IF;

            RCardInfo.CardCurrency := v_country_rec.currency_code;
            RCardInfo.CountryCode := v_country_rec.country_code;

            RCardInfo.AccountSource := NULL /*TODO*/;
            RCardInfo.IssuerBin := v_cup_bin_record.bin;
            v_product_id := NULL /*TODO*/;

    ELSE

                v_env_info_trace.user_message   :=      'BILLING CURRENCY NOT FOUND : [' ||PCRD_TOOLS_MISC_CHECKING.MASKED_CARD_NUMBER(p_card_number) || ']['|| p_network ||']';

                PCRD_GENERAL_TOOLS.PUT_TRACES  (v_env_info_trace,$$PLSQL_LINE );
                    RETURN(declaration_cst.NOK);
             ---En attendant sortir IL FUAT CHERCHER D'ou ON PEUT AVOIR LE BILLING CURRENCY POUR NETWORK_AMEX , NETWORK_DINERS,NETWORK_JCB,NETWORK_DISCOVER
    END IF;


    BEGIN
        SELECT  card_type , class_level
        INTO    RCardInfo.CardType , RCardInfo.ClassLevel
        FROM    CARD_CLASS
        WHERE   class_id    = v_product_id;
    EXCEPTION
       WHEN OTHERS THEN
        DECLARE
            v_env_info_trace            global_vars.env_info_trace_type;
        BEGIN
                v_env_info_trace.user_name      :=  global_vars.USER_NAME;
                v_env_info_trace.module_code    :=  global_vars.ML_MISC;
                v_env_info_trace.package_name   :=  $$PLSQL_UNIT;
                v_env_info_trace.function_name  :=  'GET_INFO_CARD';
                v_env_info_trace.lang           :=  global_vars.LANG;

                v_env_info_trace.user_message   :=      'NO_DATA_FOUND in CARD_CLASS, p_card_number : ['    ||PCRD_TOOLS_MISC_CHECKING.MASKED_CARD_NUMBER(p_card_number)||']'||
                                                        ' p_network : ['    ||p_network||']';

                PCRD_GENERAL_TOOLS.PUT_TRACES  (v_env_info_trace,$$PLSQL_LINE );
        END;
    END;





    RETURN(DECLARATION_CST.OK);
EXCEPTION
        WHEN NO_DATA_FOUND THEN
        DECLARE
            v_env_info_trace            global_vars.env_info_trace_type;
        BEGIN
                v_env_info_trace.user_name      :=  global_vars.USER_NAME;
                v_env_info_trace.module_code    :=  global_vars.ML_MISC;
                v_env_info_trace.package_name   :=  $$PLSQL_UNIT;
                v_env_info_trace.function_name  :=  'GET_INFO_CARD';
                v_env_info_trace.lang           :=  global_vars.LANG;

                v_env_info_trace.user_message   :=      'NO_DATA_FOUND p_card_number : ['    ||PCRD_TOOLS_MISC_CHECKING.MASKED_CARD_NUMBER(p_card_number)||']'||
                                                        ' p_network : ['    ||p_network||']';

                PCRD_GENERAL_TOOLS.PUT_TRACES  (v_env_info_trace,$$PLSQL_LINE );
                RETURN(declaration_cst.NOK);
        END;
        WHEN OTHERS THEN
        DECLARE
            v_env_info_trace            global_vars.env_info_trace_type;
        BEGIN
                v_env_info_trace.user_name      :=  global_vars.USER_NAME;
                v_env_info_trace.module_code    :=  global_vars.ML_MISC;
                v_env_info_trace.package_name   :=  $$PLSQL_UNIT;
                v_env_info_trace.function_name  :=  'GET_INFO_CARD';
                v_env_info_trace.lang           :=  global_vars.LANG;

                v_env_info_trace.user_message   :=  'Error In Function GET_INFO_CARD';
                PCRD_GENERAL_TOOLS.PUT_TRACES  (v_env_info_trace,$$PLSQL_LINE );
                RETURN(DECLARATION_CST.ERROR);
     END;
END GET_INFO_CARD;
/*END:ZKO16092018*/
-----------------------------------------------------------------------------------------------------------------------------------------------
END PCRD_P7_LOAD_ISS_DATA;
/

-- Grants for Package Body
GRANT EXECUTE ON pcrd_p7_load_iss_data TO chamon
/
GRANT EXECUTE ON pcrd_p7_load_iss_data TO verkio
/
GRANT EXECUTE ON pcrd_p7_load_iss_data TO annaza
/
GRANT EXECUTE ON pcrd_p7_load_iss_data TO petnya
/
GRANT EXECUTE ON pcrd_p7_load_iss_data TO shagoo
/
GRANT EXECUTE ON pcrd_p7_load_iss_data TO yeehos
/
GRANT EXECUTE ON pcrd_p7_load_iss_data TO shahos
/
GRANT EXECUTE ON pcrd_p7_load_iss_data TO isfbun
/
GRANT EXECUTE ON pcrd_p7_load_iss_data TO dirjau
/
GRANT EXECUTE ON pcrd_p7_load_iss_data TO mamjug
/
GRANT EXECUTE ON pcrd_p7_load_iss_data TO nawkho
/
GRANT EXECUTE ON pcrd_p7_load_iss_data TO davlen
/
GRANT EXECUTE ON pcrd_p7_load_iss_data TO paslou
/
GRANT EXECUTE ON pcrd_p7_load_iss_data TO anamad
/
GRANT EXECUTE ON pcrd_p7_load_iss_data TO mahrah
/
GRANT EXECUTE ON pcrd_p7_load_iss_data TO ashtap
/
GRANT EXECUTE ON pcrd_p7_load_iss_data TO yanvee
/
GRANT EXECUTE ON pcrd_p7_load_iss_data TO lavli
/
GRANT EXECUTE ON pcrd_p7_load_iss_data TO amrooz
/
GRANT EXECUTE ON pcrd_p7_load_iss_data TO visbee
/
GRANT EXECUTE ON pcrd_p7_load_iss_data TO vimgov
/
GRANT EXECUTE ON pcrd_p7_load_iss_data TO samdom
/


-- End of DDL Script for Package Body POWERV3FE.PCRD_P7_LOAD_ISS_DATA

