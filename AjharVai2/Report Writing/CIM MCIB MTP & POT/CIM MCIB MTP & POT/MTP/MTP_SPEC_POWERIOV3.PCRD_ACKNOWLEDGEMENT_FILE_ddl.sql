-- Start of DDL Script for Package POWERIOV3.PCRD_ACKNOWLEDGEMENT_FILE
-- Generated 21-Nov-2023 09:50:09 from POWERIOV3@(DESCRIPTION =(ADDRESS_LIST =(ADDRESS = (PROTOCOL = TCP)(HOST = 172.17.8.90)(PORT = 1530)))(CONNECT_DATA =(SERVICE_NAME = afcv3)))

CREATE OR REPLACE 
PACKAGE pcrd_acknowledgement_file   IS
-------------------------------------------------------------------------------------------------------------
FUNCTION  LOAD_ACKNOWLEDGEMENT              (  p_business_date           IN   DATE,
                                               p_task_name               IN   pcard_tasks.task_name%TYPE,
                                               p_physical_file_name      IN   PCRD_FILE_PROCESSING.physical_file_name%TYPE)
                                           RETURN PLS_INTEGER;
-------------------------------------------------------------------------------------------------------------
FUNCTION    PUT_ACK_FILE_HEADER    (       p_seq_num                      IN           ACK_FILE_BUFFER.sequence_number%TYPE)
                                                RETURN PLS_INTEGER;
-------------------------------------------------------------------------------------------------------------
FUNCTION    PUT_ACK_FILE_DETAIL    (       p_seq_num                      IN           ACK_FILE_BUFFER.sequence_number%TYPE)
                                                RETURN PLS_INTEGER;
-------------------------------------------------------------------------------------------------------------
FUNCTION    PUT_ACK_MAPPING_TABLE   (       p_rec_no           IN ACK_MAPPING_TABLE.RECORD_NO%TYPE,
                                            p_file_name        IN ack_file_header.FILE_NAME%TYPE,
                                            p_seq_no           IN ack_file_detail.sequence_number%TYPE)
                                                RETURN PLS_INTEGER; --ADDED BY MH23012022

-------------------------------------------------------------------------------------------------------------
FUNCTION    PUT_ACK_FILE_SUCCESS   (        p_rec_no           IN ACK_MAPPING_TABLE.RECORD_NO%TYPE,
                                            p_file_name        IN ack_file_header.FILE_NAME%TYPE,
                                            p_seq_no           IN ack_file_detail.sequence_number%TYPE,
                                           p_status_msg        IN VARCHAR2 )
                                                RETURN PLS_INTEGER;

-------------------------------------------------------------------------------------------------------------
FUNCTION    PUT_ACK_FILE_REJECT   (        p_rec_no                       IN           ACK_MAPPING_TABLE.RECORD_NO%TYPE,
                                        p_file_name        IN ack_file_header.FILE_NAME%TYPE,
                                        p_seq_no           IN ack_file_detail.sequence_number%TYPE,
                                           p_status_msg        IN VARCHAR2 )
                                                RETURN PLS_INTEGER;
-------------------------------------------------------------------------------------------------------------
FUNCTION    CHECKS_FILE_PROCESSING (       p_pcrd_file_processing_rec     IN      PCRD_FILE_PROCESSING%ROWTYPE)
                                                RETURN PLS_INTEGER;
-------------------------------------------------------------------------------------------------------------
FUNCTION    PROC_ACK_FILE_PROC_DETAIL (    p_business_date           IN   DATE,
                                           p_task_name               IN   pcard_tasks.task_name%TYPE,
                                           P_internal_file_name      IN   PCRD_FILE_PROCESSING.internal_file_name%TYPE,
                                           p_physical_file_name      IN   PCRD_FILE_PROCESSING.physical_file_name%TYPE,
                                           p_seq_num                 IN   ACK_FILE_BUFFER.sequence_number%TYPE,
                                           p_is_file_already_processed IN PLS_INTEGER)
                                                RETURN PLS_INTEGER;
-------------------------------------------------------------------------------------------------------------
FUNCTION    PROCESS_ACK_FILE_DETAIL_TABLE (    --p_business_date           IN   DATE,
                                           --p_task_name               IN   pcard_tasks.task_name%TYPE,
                                          -- P_internal_file_name      IN   PCRD_FILE_PROCESSING.internal_file_name%TYPE,
                                          -- p_physical_file_name      IN   PCRD_FILE_PROCESSING.physical_file_name%TYPE,
                                            p_seq_num                 IN   ACK_FILE_DETAIL.sequence_number%TYPE)
                                          -- p_rec_no                 IN   ACK_FILE_DETAIL.RECORD_NO%TYPE)
                                          -- p_is_file_already_processed IN PLS_INTEGER)
                                                RETURN PLS_INTEGER;
-------------------------------------------------------------------------------------------------------------

FUNCTION    PROC_ACK_FILE_PROC_HEADER (    p_business_date           IN   DATE,
                                           p_task_name               IN   pcard_tasks.task_name%TYPE,
                                           p_seq_num                 IN   ACK_FILE_BUFFER.sequence_number%TYPE)
                                                RETURN PLS_INTEGER;
-------------------------------------------------------------------------------------------------------------
FUNCTION    ARCHIVE_TABLES          RETURN PLS_INTEGER;
-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------
FUNCTION    ARCHIVE_SUCCESS_REJECT_TABLES          RETURN PLS_INTEGER;    -- AJHAR20231113
-------------------------------------------------------------------------------------------------------------
FUNCTION    UPDATE_ACK_MAPPING_TABLE   (    p_ref_no           IN ack_file_detail.REF_NO%TYPE,
                                            p_rec_no           IN ack_file_detail.RECORD_NO%TYPE,
                                            P_ENTITY_CODE      IN ack_file_detail.ENTITY_CODE%TYPE,
                                            P_FILE_NAME        IN ack_file_header.FILE_NAME%TYPE,
                                            p_seq_no           IN ack_file_detail.sequence_number%TYPE
                                        )
                                          RETURN PLS_INTEGER;
-------------------------------------------------------------------------------------------------------------
END PCRD_ACKNOWLEDGEMENT_FILE;
/

-- Grants for Package
GRANT EXECUTE ON pcrd_acknowledgement_file TO icps_power_cim
/


-- End of DDL Script for Package POWERIOV3.PCRD_ACKNOWLEDGEMENT_FILE

