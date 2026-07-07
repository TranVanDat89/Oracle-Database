create or replace TRIGGER "TRG_TRADE_FINANCE_MANAGEMENT_LOG" 
AFTER INSERT OR UPDATE
ON BB_TRADE_FINANCE_MANAGEMENT
FOR EACH ROW
DECLARE
    v_status VARCHAR2(20);
    v_channel_code VARCHAR2(20);
    v_remarks CLOB;
    v_apply_name VARCHAR2(20);
    v_assignee VARCHAR2(20);
    v_syscode VARCHAR2(20);
    v_attachment_id VARCHAR2(200);
    v_time TIMESTAMP;
    v_trade_type VARCHAR2(200);
BEGIN
    v_status := :NEW.STATUS;
    v_assignee := 'PGBank';
    v_channel_code := 'BK';
    v_syscode := 'BK';
    v_trade_type := :NEW.TRADE_TYPE;
    DBMS_OUTPUT.PUT_LINE('STATUS = ' || v_status);
    IF v_status IN ('SUPP', 'RJCT', 'PROC', 'SUCC') THEN
        v_channel_code := 'BK';
        v_syscode := 'BK';
        CASE v_status
            WHEN 'SUCC' THEN
                v_apply_name := 'done';
                v_status := 'success';
            WHEN 'SUPP' THEN
                v_remarks := :NEW.RESPONSE_CONTENT;
                v_apply_name := 'supp';
                v_status := 'supplement documents';
                v_attachment_id := :NEW.RESPONSE_FILE_ID;
            WHEN 'PROC' THEN
                v_apply_name := 'accept';
                v_status := 'accept request';
            WHEN 'RJCT' THEN
                v_apply_name := 'reject';
                v_status := 'reject request';
        END CASE;
        v_time := SYSTIMESTAMP;
        INSERT INTO WF_LOG_INFO(LOG_ID, WF_PROCESS_ID, APPLY_NAME, STATUS, START_TIME, END_TIME, REMARKS, ASSIGNEE, SYS_CODE, APPROVE_CHANNEL, TRAN_SN, REQUEST_ID, ATTACHMENT_ID)
        VALUES(SEQ_WF_LOG_ID.nextval, :NEW.WF_PROCESS_ID, v_apply_name, v_status, v_time, v_time, v_remarks, v_assignee, v_syscode, v_channel_code, :NEW.TRAN_SN, :NEW.REQUEST_ID, v_attachment_id);
    END IF;

    -- TH Yêu cầu tư vấn từ Đề nghị phát hành LC
    IF v_trade_type = 'LC_ADVICE' AND v_status = 'PEND' THEN
        v_apply_name := 'send';
        v_status := 'send request';
        v_time := SYSTIMESTAMP;
        INSERT INTO WF_LOG_INFO(LOG_ID, WF_PROCESS_ID, APPLY_NAME, STATUS, START_TIME, END_TIME, REMARKS, ASSIGNEE, SYS_CODE, APPROVE_CHANNEL, TRAN_SN, REQUEST_ID, ATTACHMENT_ID)
        VALUES(SEQ_WF_LOG_ID.nextval, :NEW.WF_PROCESS_ID, v_apply_name, v_status, v_time, v_time, v_remarks, v_assignee, v_syscode, v_channel_code, :NEW.TRAN_SN, :NEW.REQUEST_ID, v_attachment_id);
    END IF;
END;
/

create or replace TRIGGER TRG_LC_CONSULT_REQUEST_LOG
AFTER INSERT OR UPDATE
ON LC_CONSULT_REQUEST
FOR EACH ROW
DECLARE
    v_status VARCHAR2(20);
    v_status_old VARCHAR2(20);
    v_channel_code VARCHAR2(20);
    v_remarks VARCHAR2(20);
    v_apply_name VARCHAR2(20);
    v_assignee VARCHAR2(20);
    v_syscode VARCHAR2(20);
    v_time TIMESTAMP;
BEGIN
    v_status := :NEW.STATUS;
    v_status_old := :OLD.STATUS;
    
    -- TH Bổ sung thông tin
    IF v_status = 'SUCC' and v_status_old = 'SUCC' THEN
        v_status := 'SUPP';
    END IF;
    
    v_assignee := 'PGBank';
    DBMS_OUTPUT.PUT_LINE('STATUS = ' || v_status);
    IF v_status IN ('PEND', 'SUCC', 'SUPP') THEN
        v_channel_code := 'BK';
        v_syscode := 'BK';

        CASE v_status
            WHEN 'SUCC' THEN
                v_apply_name := 'done';
                v_status := 'success';
            WHEN 'SUPP' THEN
                v_remarks := :NEW.RESPONSE_CONTENT;
                v_apply_name := 'suppad';
                v_status := 'supplement documents';
            WHEN 'PEND' THEN
                v_apply_name := 'send';
                v_status := 'send request';
        END CASE;
        v_time := SYSTIMESTAMP;
        INSERT INTO WF_LOG_INFO(LOG_ID, APPLY_NAME, STATUS, START_TIME, END_TIME, REMARKS, ASSIGNEE, SYS_CODE, APPROVE_CHANNEL, REQUEST_ID, USER_ID)
        VALUES(SEQ_WF_LOG_ID.nextval, v_apply_name, v_status, v_time, v_time, v_remarks, v_assignee, v_syscode, v_channel_code, :NEW.REQUEST_ID, :NEW.CREATE_BY);
    END IF;
END;