-- Type "con": dùng cho các phần tử bên trong trans (approved logs + pending placeholders)
CREATE OR REPLACE TYPE t_transaction_child AS OBJECT (
    log_id           VARCHAR2(50),
    wf_process_id    VARCHAR2(50),
    apply_name       VARCHAR2(50),
    title            VARCHAR2(200),
    status           VARCHAR2(50),
    start_time       TIMESTAMP,
    end_time         TIMESTAMP,
    remarks          VARCHAR2(4000),
    assignee         VARCHAR2(4000),
    approve_channel  VARCHAR2(50),
    tran_sn          VARCHAR2(50),
    request_id       VARCHAR2(50),
    user_name        VARCHAR2(100),
    full_name        VARCHAR2(200),
    attachment_ids   VARCHAR2(4000),
    is_active        VARCHAR2(1),   
    is_pending       VARCHAR2(1)    
);
/

CREATE OR REPLACE TYPE t_transaction_child_tab AS TABLE OF t_transaction_child;
/

CREATE OR REPLACE TYPE t_transaction_file AS OBJECT (
    attachment_id    VARCHAR2(50),
    file_name        VARCHAR2(500)
);
/
 
CREATE OR REPLACE TYPE t_transaction_file_tab AS TABLE OF t_transaction_file;
/
 
-- Type "cha": mỗi phần tử của kết quả trả về, có thêm field trans
CREATE OR REPLACE TYPE t_transaction_history AS OBJECT (
    log_id           VARCHAR2(50),
    wf_process_id    VARCHAR2(50),
    apply_name       VARCHAR2(50),
    title            VARCHAR2(200),
    status           VARCHAR2(50),
    start_time       TIMESTAMP,
    end_time         TIMESTAMP,
    remarks          VARCHAR2(4000),
    assignee         VARCHAR2(4000),
    approve_channel  VARCHAR2(50),
    tran_sn          VARCHAR2(50),
    request_id       VARCHAR2(50),
    user_name        VARCHAR2(100),
    full_name        VARCHAR2(200),
    attachment_ids   VARCHAR2(4000),
    is_active        VARCHAR2(1),
    is_pending       VARCHAR2(1),
    files            t_transaction_file_tab,
    trans            t_transaction_child_tab
);
/
 
CREATE OR REPLACE TYPE t_transaction_history_tab AS TABLE OF t_transaction_history;
/

--------------------------------------------------------------------------------
-- Type mới, tầng ngoài cùng: "Ngày" -- bọc quanh kết quả build_transantion_history
-- (list các entry: log đơn lẻ HOẶC nhóm task đã gộp), thêm field time_key.
-- Dependency 1 chiều: t_transaction_child -> t_transaction_history -> t_transaction_day
-- (không có vòng lặp, không đụng tới ORA-04055 đã gặp trước đây).
--------------------------------------------------------------------------------
CREATE OR REPLACE TYPE t_transaction_day AS OBJECT (
    time_key VARCHAR2(20),            -- format dd/MM/yyyy
    trans    t_transaction_history_tab
);
/
 
CREATE OR REPLACE TYPE t_transaction_day_tab AS TABLE OF t_transaction_day;
/

--------------------------------------------------------------------------------
-- 2. PACKAGE SPEC
--------------------------------------------------------------------------------
CREATE OR REPLACE
PACKAGE pkg_wf_process_builder AS
    FUNCTION build_process(
        p_request_id IN VARCHAR2,
        p_corp_id    IN NUMBER,
        p_language   IN VARCHAR2,
        p_service_type IN VARCHAR2
    ) RETURN t_transaction_history_tab PIPELINED;
    
    FUNCTION build_transaction_history_by_time(
        p_request_id   IN VARCHAR2,
        p_corp_id      IN NUMBER,
        p_language     IN VARCHAR2,
        p_service_type IN VARCHAR2
    ) RETURN t_transaction_day_tab PIPELINED;

    FUNCTION build_process_json(
        p_request_id IN VARCHAR2,
        p_corp_id    IN NUMBER,
        p_language   IN VARCHAR2,
        p_service_type IN VARCHAR2
    ) RETURN CLOB;
    
    FUNCTION build_transaction_history_json(
        p_request_id IN VARCHAR2,
        p_corp_id    IN NUMBER,
        p_language   IN VARCHAR2,
        p_service_type IN VARCHAR2
    ) RETURN CLOB;

END pkg_wf_process_builder;
/
create or replace PACKAGE BODY pkg_wf_process_builder AS
 
    FUNCTION build_process(
        p_request_id IN VARCHAR2,
        p_corp_id    IN NUMBER,
        p_language   IN VARCHAR2,
        p_service_type IN VARCHAR2
    ) RETURN t_transaction_history_tab PIPELINED IS
 
        TYPE t_log_row IS RECORD (
            log_id          WF_LOG_INFO.LOG_ID%TYPE,
            wf_process_id   WF_LOG_INFO.WF_PROCESS_ID%TYPE,
            apply_name      WF_LOG_INFO.APPLY_NAME%TYPE,
            status          WF_LOG_INFO.STATUS%TYPE,
            start_time      WF_LOG_INFO.START_TIME%TYPE,
            end_time        WF_LOG_INFO.END_TIME%TYPE,
            remarks         WF_LOG_INFO.REMARKS%TYPE,
            assignee        WF_LOG_INFO.ASSIGNEE%TYPE,
            approve_channel WF_LOG_INFO.APPROVE_CHANNEL%TYPE,
            tran_sn         WF_LOG_INFO.TRAN_SN%TYPE,
            request_id      WF_LOG_INFO.REQUEST_ID%TYPE,
            user_name       BB_USER_INFO.USER_NAME%TYPE,
            full_name       BB_USER_INFO.FULL_NAME%TYPE
        );
        TYPE t_log_tab IS TABLE OF t_log_row INDEX BY PLS_INTEGER;
        v_logs t_log_tab;

        v_trade_type    VARCHAR2(50);
        v_ignore_approve  BOOLEAN := TRUE;
        v_last_tran     t_log_row;

        TYPE t_level_names IS TABLE OF VARCHAR2(4000) INDEX BY PLS_INTEGER;
        v_level_names    t_level_names;
        v_max_level      PLS_INTEGER;
        v_current_level  PLS_INTEGER;
        v_approved_count PLS_INTEGER;

        v_pro        t_transaction_history;
        v_tran_list  t_transaction_child_tab;

    BEGIN
        DECLARE
            i PLS_INTEGER := 0;
        BEGIN
            -- Lấy danh sách bảng WF_LOG_INFO
            FOR r IN (
                SELECT log.LOG_ID, log.WF_PROCESS_ID, log.APPLY_NAME, log.STATUS,
                       log.START_TIME, log.END_TIME, log.REMARKS, log.ASSIGNEE,
                       log.APPROVE_CHANNEL, log.TRAN_SN, log.REQUEST_ID,
                       u.USER_NAME, u.FULL_NAME
                  FROM WF_LOG_INFO log
                  LEFT JOIN BB_USER_INFO u ON u.USER_ID = log.USER_ID
                 WHERE log.REQUEST_ID = p_request_id
                 ORDER BY log.LOG_ID
            ) LOOP
                i := i + 1;
                v_logs(i).log_id          := r.LOG_ID;
                v_logs(i).wf_process_id   := r.WF_PROCESS_ID;
                v_logs(i).apply_name      := r.APPLY_NAME;
                v_logs(i).status          := r.STATUS;
                v_logs(i).start_time      := r.START_TIME;
                v_logs(i).end_time        := r.END_TIME;
                v_logs(i).remarks         := r.REMARKS;
                v_logs(i).assignee        := r.ASSIGNEE;
                v_logs(i).approve_channel := r.APPROVE_CHANNEL;
                v_logs(i).tran_sn         := r.TRAN_SN;
                v_logs(i).request_id      := r.REQUEST_ID;
                v_logs(i).user_name       := r.USER_NAME;
                v_logs(i).full_name       := r.FULL_NAME;
            END LOOP;
        END;

        IF v_logs.COUNT = 0 THEN
            RETURN; -- trả list rỗng
        END IF;

        v_last_tran := v_logs(v_logs.LAST); -- logInfo.get(0), do đã ORDER BY LOG_ID DESC

        -- Yêu cầu tư vấn bỏ bước APPROVE
        IF p_service_type = 'TF' THEN
            BEGIN
                SELECT TRADE_TYPE INTO v_trade_type
                FROM BB_TRADE_FINANCE_MANAGEMENT
                WHERE WF_PROCESS_ID = v_last_tran.wf_process_id;
                v_ignore_approve := (v_trade_type = 'LC_ADVICE');
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    v_ignore_approve := TRUE; -- tradeFinance == null coi như LC_ADVICE
            END;
        END IF;

        --------------------------------------------------------------------
        --  Lặp qua danh sách step cấu hình (PROCESS_TITLE)
        --------------------------------------------------------------------
        FOR step IN (
            SELECT C_VALUES AS step_key,
                   CASE 
                        WHEN LOWER(p_language) = 'vi_vn' 
                        THEN C_DESCRIPTION 
                        ELSE C_DESCRIPTION_ENGLISH 
                    END AS step_title
              FROM BK_COMBOBOX
             WHERE C_TABLE_NAME = 'PROCESS_TITLE'
             ORDER BY C_SEQ
        ) LOOP

            IF step.step_key = 'APPROVE' AND v_ignore_approve THEN
                CONTINUE; 
            END IF;

            v_pro := t_transaction_history(
                log_id => NULL, wf_process_id => NULL, apply_name => step.step_key,
                title => step.step_title, status => NULL, start_time => NULL, end_time => NULL,
                remarks => NULL, assignee => NULL, approve_channel => NULL, tran_sn => NULL,
                request_id => p_request_id, user_name => NULL, full_name => NULL,
                attachment_ids => NULL, is_active => 'N', is_pending => 'N', 
                files => NULL,  
                trans => NULL
            );

            ----------------------------------------------------------------
            -- INIT
            ----------------------------------------------------------------
            IF step.step_key = 'INIT' THEN
                FOR i IN 1 .. v_logs.COUNT LOOP
                    IF v_logs(i).apply_name IN ('send', 'start1') THEN
                        v_pro.full_name  := v_logs(i).full_name;
                        v_pro.user_name  := v_logs(i).user_name;
                        v_pro.assignee   := v_logs(i).assignee;
                        v_pro.start_time := v_logs(i).start_time;
                        EXIT;
                    END IF;
                END LOOP;

            ----------------------------------------------------------------
            -- APPROVE
            ----------------------------------------------------------------
            ELSIF step.step_key = 'APPROVE' THEN
                v_level_names.DELETE;
                v_max_level := 0;

                FOR a IN (
                    SELECT PROCESS_LEVEL, USER_NAME
                      FROM TABLE(pkg_wf_assignee_info.get_assignee_allowed(p_corp_id, v_last_tran.wf_process_id))
                ) LOOP
                    IF v_level_names.EXISTS(a.PROCESS_LEVEL) THEN
                        v_level_names(a.PROCESS_LEVEL) := v_level_names(a.PROCESS_LEVEL) || ' / ' || a.USER_NAME;
                    ELSE
                        v_level_names(a.PROCESS_LEVEL) := a.USER_NAME;
                    END IF;
                    IF a.PROCESS_LEVEL > v_max_level THEN
                        v_max_level := a.PROCESS_LEVEL;
                    END IF;
                END LOOP;

                v_tran_list := t_transaction_child_tab();
                v_approved_count := 0;

                -- Các log "task*" đã approve, cùng wf_process_id với lastTran
                FOR i IN 1 .. v_logs.COUNT LOOP
                    IF v_logs(i).wf_process_id = v_last_tran.wf_process_id
                       AND v_logs(i).apply_name LIKE 'task%'
                       AND v_logs(i).status = 'approve' THEN

                        v_approved_count := v_approved_count + 1;
                        v_tran_list.EXTEND;
                        v_tran_list(v_tran_list.LAST) := t_transaction_child(
                            log_id => v_logs(i).log_id, wf_process_id => v_logs(i).wf_process_id,
                            apply_name => v_logs(i).apply_name, title => NULL, status => v_logs(i).status,
                            start_time => v_logs(i).start_time, end_time => v_logs(i).end_time,
                            remarks => v_logs(i).remarks, assignee => v_logs(i).full_name,
                            approve_channel => v_logs(i).approve_channel, tran_sn => v_logs(i).tran_sn,
                            request_id => v_logs(i).request_id, user_name => v_logs(i).user_name,
                            full_name => v_logs(i).full_name, attachment_ids => NULL,
                            is_active => 'N', is_pending => 'N'
                        );
                    END IF;
                END LOOP;

                -- Các level còn lại -> pending
                v_current_level := v_approved_count + 1;
                v_pro.is_active := CASE WHEN v_current_level <= v_max_level THEN 'Y' ELSE 'N' END;

                WHILE v_current_level <= v_max_level LOOP
                    v_tran_list.EXTEND;
                    v_tran_list(v_tran_list.LAST) := t_transaction_child(
                        log_id => NULL, wf_process_id => NULL, apply_name => NULL, title => NULL,
                        status => NULL, start_time => NULL, end_time => NULL, remarks => NULL,
                        assignee => NVL(v_level_names(v_current_level), ''), approve_channel => NULL,
                        tran_sn => NULL, request_id => NULL, user_name => NULL, full_name => NULL,
                        attachment_ids => NULL, is_active => 'N', is_pending => 'Y'
                    );
                    v_current_level := v_current_level + 1;
                END LOOP;

                v_pro.trans := v_tran_list;

            ----------------------------------------------------------------
            -- BANKPROCESS
            ----------------------------------------------------------------
            ELSIF step.step_key = 'BANKPROCESS' THEN
                v_pro.is_active := CASE
                    WHEN v_last_tran.apply_name IN ('end1', 'accept', 'send') THEN 'Y'
                    ELSE 'N'
                END;
                v_pro.assignee := 'PGBank';

            ----------------------------------------------------------------
            -- DONE
            ----------------------------------------------------------------
            ELSIF step.step_key = 'DONE' THEN
                v_pro.is_active := 'N';
                FOR i IN 1 .. v_logs.COUNT LOOP
                    IF v_logs(i).apply_name = 'done' THEN
                        v_pro.is_active := 'Y';
                        EXIT;
                    END IF;
                END LOOP;
                v_pro.assignee := 'PGBank';
            END IF;

            PIPE ROW (v_pro);

        END LOOP;

        RETURN;

    END build_process;

    FUNCTION build_transaction_history_by_time(
        p_request_id   IN VARCHAR2,
        p_corp_id      IN NUMBER,
        p_language     IN VARCHAR2,
        p_service_type IN VARCHAR2
    ) RETURN t_transaction_day_tab PIPELINED IS

        TYPE t_log_row IS RECORD (
            log_id          WF_LOG_INFO.LOG_ID%TYPE,
            wf_process_id   WF_LOG_INFO.WF_PROCESS_ID%TYPE,
            apply_name      WF_LOG_INFO.APPLY_NAME%TYPE,
            status          WF_LOG_INFO.STATUS%TYPE,
            start_time      WF_LOG_INFO.START_TIME%TYPE,
            end_time        WF_LOG_INFO.END_TIME%TYPE,
            remarks         WF_LOG_INFO.REMARKS%TYPE,
            assignee        WF_LOG_INFO.ASSIGNEE%TYPE,
            approve_channel WF_LOG_INFO.APPROVE_CHANNEL%TYPE,
            tran_sn         WF_LOG_INFO.TRAN_SN%TYPE,
            request_id      WF_LOG_INFO.REQUEST_ID%TYPE,
            user_name       BB_USER_INFO.USER_NAME%TYPE,
            full_name       BB_USER_INFO.FULL_NAME%TYPE,
            attachment_id   WF_LOG_INFO.ATTACHMENT_ID%TYPE
        );
        TYPE t_log_tab IS TABLE OF t_log_row INDEX BY PLS_INTEGER;

        v_logs t_log_tab;

        TYPE t_key_tab IS TABLE OF VARCHAR2(50) INDEX BY PLS_INTEGER;
        v_task_keys t_key_tab;   -- task-key chuẩn hoá theo từng dòng (giống tran.setTitle(applyName) trong Java)
        TYPE t_date_tab IS TABLE OF VARCHAR2(20) INDEX BY PLS_INTEGER;
        v_date_keys t_date_tab;  -- ngày (dd/MM/yyyy) theo từng dòng

        TYPE t_title_map IS TABLE OF VARCHAR2(200) INDEX BY VARCHAR2(50);
        v_title_map t_title_map;

        TYPE t_idx_nt IS TABLE OF PLS_INTEGER;
        empty_idx_nt t_idx_nt := t_idx_nt();

        TYPE t_date_map IS TABLE OF t_idx_nt INDEX BY VARCHAR2(20);
        v_date_map       t_date_map;
        TYPE t_date_order_tab IS TABLE OF VARCHAR2(20) INDEX BY PLS_INTEGER;
        v_date_order      t_date_order_tab;
        v_date_order_cnt  PLS_INTEGER := 0;

        TYPE t_group_map IS TABLE OF t_idx_nt INDEX BY VARCHAR2(200);
        v_group_map       t_group_map;
        TYPE t_group_order_tab IS TABLE OF VARCHAR2(200) INDEX BY PLS_INTEGER;
        v_group_order      t_group_order_tab;
        v_group_order_cnt  PLS_INTEGER := 0;

        v_day_trans   t_transaction_history_tab;
        v_tran_list   t_transaction_child_tab;

        v_date_idx_list t_idx_nt;
        v_gkey          VARCHAR2(200);
        v_i             PLS_INTEGER;
        v_d             VARCHAR2(20);

        FUNCTION get_title(p_key VARCHAR2) RETURN VARCHAR2 IS
        BEGIN
            IF v_title_map.EXISTS(p_key) THEN
                RETURN v_title_map(p_key);
            END IF;
            RETURN p_key;
        END get_title;

        FUNCTION resolve_files(p_attachment_ids IN VARCHAR2) RETURN t_transaction_file_tab IS
            v_files t_transaction_file_tab := t_transaction_file_tab();
        BEGIN
            IF p_attachment_ids IS NULL THEN
                RETURN NULL;
            END IF;

            FOR f IN (
                SELECT a.ATTACHMENT_ID, a.FILE_NAME
                  FROM BK_CMS_FILE_ATTACHMENT a
                 WHERE a.ATTACHMENT_ID IN (
                     SELECT TO_NUMBER(TRIM(REGEXP_SUBSTR(p_attachment_ids, '[^,]+', 1, LEVEL)))
                       FROM DUAL
                     CONNECT BY REGEXP_SUBSTR(p_attachment_ids, '[^,]+', 1, LEVEL) IS NOT NULL
                 )
            ) LOOP
                v_files.EXTEND;
                v_files(v_files.LAST) := t_transaction_file(
                    attachment_id => TO_CHAR(f.ATTACHMENT_ID),
                    file_name     => f.FILE_NAME
                );
            END LOOP;

            IF v_files.COUNT = 0 THEN
                RETURN NULL; -- không tìm thấy file nào khớp -> để NULL thay vì mảng rỗng
            END IF;

            RETURN v_files;
        END resolve_files;

        FUNCTION build_leaf(p_indices IN t_idx_nt) RETURN t_transaction_history IS
            v_first PLS_INTEGER;
        BEGIN
            v_first := p_indices(p_indices.FIRST);

            IF p_indices.COUNT = 1 THEN
                RETURN t_transaction_history(
                    log_id => v_logs(v_first).log_id, wf_process_id => v_logs(v_first).wf_process_id,
                    apply_name => v_logs(v_first).apply_name, title => get_title(v_task_keys(v_first)),
                    status => v_logs(v_first).status, start_time => v_logs(v_first).start_time,
                    end_time => v_logs(v_first).end_time, remarks => v_logs(v_first).remarks,
                    assignee => v_logs(v_first).assignee, approve_channel => v_logs(v_first).approve_channel,
                    tran_sn => v_logs(v_first).tran_sn, request_id => v_logs(v_first).request_id,
                    user_name => v_logs(v_first).user_name, full_name => v_logs(v_first).full_name,
                    attachment_ids => NULL, is_active => 'N', is_pending => 'N',
                    files => resolve_files(v_logs(v_first).attachment_id), 
                    trans => NULL
                );
            END IF;

            v_tran_list := t_transaction_child_tab();
            FOR m IN p_indices.FIRST .. p_indices.LAST LOOP
                DECLARE
                    idx PLS_INTEGER := p_indices(m);
                BEGIN
                    v_tran_list.EXTEND;
                    v_tran_list(v_tran_list.LAST) := t_transaction_child(
                        log_id => v_logs(idx).log_id, wf_process_id => v_logs(idx).wf_process_id,
                        apply_name => v_logs(idx).apply_name, title => v_task_keys(idx),
                        status => v_logs(idx).status, start_time => v_logs(idx).start_time,
                        end_time => v_logs(idx).end_time, remarks => v_logs(idx).remarks,
                        assignee => v_logs(idx).assignee, approve_channel => v_logs(idx).approve_channel,
                        tran_sn => v_logs(idx).tran_sn, request_id => v_logs(idx).request_id,
                        user_name => v_logs(idx).user_name, full_name => v_logs(idx).full_name,
                        attachment_ids => NULL, is_active => 'N', is_pending => 'N'
                    );
                END;
            END LOOP;

            RETURN t_transaction_history(
                log_id => NULL, wf_process_id => v_logs(v_first).wf_process_id,
                apply_name => 'task', title => get_title(v_task_keys(v_first)),
                status => NULL, start_time => NULL, end_time => NULL, remarks => NULL,
                assignee => NULL, approve_channel => NULL, tran_sn => NULL, request_id => NULL,
                user_name => NULL, full_name => NULL, attachment_ids => NULL,
                is_active => 'N', is_pending => 'N', files => NULL, trans => v_tran_list
            );
        END build_leaf;

    BEGIN
        --------------------------------------------------------------------
        -- Nạp log, đánh số lại liên tục 1..n theo thứ tự LOG_ID
        --------------------------------------------------------------------
        DECLARE
            i PLS_INTEGER := 0;
        BEGIN
            FOR r IN (
                SELECT log.LOG_ID, log.WF_PROCESS_ID, log.APPLY_NAME, log.STATUS,
                       log.START_TIME, log.END_TIME, log.REMARKS, log.ASSIGNEE,
                       log.APPROVE_CHANNEL, log.TRAN_SN, log.REQUEST_ID,
                       u.USER_NAME, u.FULL_NAME, log.ATTACHMENT_ID
                  FROM WF_LOG_INFO log
                  LEFT JOIN BB_USER_INFO u ON u.USER_ID = log.USER_ID
                 WHERE log.REQUEST_ID = p_request_id
                    AND log.APPLY_NAME NOT IN ('end1', 'cancel1')
                    AND log.STATUS NOT IN ('processing')
                    AND log.END_TIME IS NOT NULL
                 ORDER BY log.LOG_ID
            ) LOOP
                i := i + 1;
                v_logs(i).log_id          := r.LOG_ID;
                v_logs(i).wf_process_id   := r.WF_PROCESS_ID;
                v_logs(i).apply_name      := r.APPLY_NAME;
                v_logs(i).status          := r.STATUS;
                v_logs(i).start_time      := r.START_TIME;
                v_logs(i).end_time        := r.END_TIME;
                v_logs(i).remarks         := r.REMARKS;
                v_logs(i).assignee        := r.ASSIGNEE;
                v_logs(i).approve_channel := r.APPROVE_CHANNEL;
                v_logs(i).tran_sn         := r.TRAN_SN;
                v_logs(i).request_id      := r.REQUEST_ID;
                v_logs(i).user_name       := r.USER_NAME;
                v_logs(i).full_name       := r.FULL_NAME;
                v_logs(i).attachment_id   := r.ATTACHMENT_ID;
                v_date_keys(i)            := TO_CHAR(r.END_TIME, 'DD/MM/YYYY');
            END LOOP;
        END;

        IF v_logs.COUNT = 0 THEN
            RETURN;
        END IF;

        -- Dictionary title
        FOR t IN (
            SELECT C_VALUES AS title_key,
                   CASE WHEN LOWER(p_language) = 'vi_vn'
                        THEN C_DESCRIPTION
                        ELSE C_DESCRIPTION_ENGLISH
                   END AS title_value
              FROM BK_COMBOBOX
             WHERE C_TABLE_NAME = 'TRANSACTION_HISTORIES_TITLE'
        ) LOOP
            v_title_map(t.title_key) := t.title_value;
        END LOOP;

        FOR i IN 1 .. v_logs.COUNT LOOP
            IF v_logs(i).apply_name LIKE 'task%' THEN
                v_task_keys(i) := CASE WHEN v_logs(i).status = 'reject' THEN 'reject' ELSE 'task' END;
            ELSE
                v_task_keys(i) := v_logs(i).apply_name;
            END IF;
        END LOOP;
        
        FOR i IN 1 .. v_logs.COUNT LOOP
            v_d := v_date_keys(i);
            IF NOT v_date_map.EXISTS(v_d) THEN
                v_date_map(v_d) := empty_idx_nt;
                v_date_order_cnt := v_date_order_cnt + 1;
                v_date_order(v_date_order_cnt) := v_d;
            END IF;
            v_date_map(v_d).EXTEND;
            v_date_map(v_d)(v_date_map(v_d).LAST) := i;
        END LOOP;

        FOR k IN 1 .. v_date_order_cnt LOOP
            v_d := v_date_order(k);
            v_date_idx_list := v_date_map(v_d);

            v_group_map.DELETE;
            v_group_order.DELETE;
            v_group_order_cnt := 0;

            FOR m IN v_date_idx_list.FIRST .. v_date_idx_list.LAST LOOP
                v_i := v_date_idx_list(m);
                v_gkey := v_task_keys(v_i) || '|' || v_logs(v_i).wf_process_id;

                IF NOT v_group_map.EXISTS(v_gkey) THEN
                    v_group_map(v_gkey) := empty_idx_nt;
                    v_group_order_cnt := v_group_order_cnt + 1;
                    v_group_order(v_group_order_cnt) := v_gkey;
                END IF;
                v_group_map(v_gkey).EXTEND;
                v_group_map(v_gkey)(v_group_map(v_gkey).LAST) := v_i;
            END LOOP;

            v_day_trans := t_transaction_history_tab();
            FOR g IN 1 .. v_group_order_cnt LOOP
                v_day_trans.EXTEND;
                v_day_trans(v_day_trans.LAST) := build_leaf(v_group_map(v_group_order(g)));
            END LOOP;

            PIPE ROW (t_transaction_day(time_key => v_d, trans => v_day_trans));
        END LOOP;

        RETURN;

    END build_transaction_history_by_time;

    FUNCTION build_process_json(
        p_request_id IN VARCHAR2,
        p_corp_id    IN NUMBER,
        p_language   IN VARCHAR2,
        p_service_type IN VARCHAR2
    ) RETURN CLOB IS

        v_json CLOB;

    BEGIN
        SELECT JSON_ARRAYAGG(
                 JSON_OBJECT(
                    'applyName'  VALUE apply_name,
                    'title'      VALUE title,
                    'status'     VALUE status,
                    'startTime'  VALUE TO_CHAR(start_time, 'YYYY-MM-DD"T"HH24:MI:SS'),
                    'endTime'    VALUE TO_CHAR(end_time, 'YYYY-MM-DD"T"HH24:MI:SS'),
                    'remarks'    VALUE remarks,
                    'assignee'   VALUE assignee,
                    'userName'   VALUE user_name,
                    'fullName'   VALUE (CASE WHEN (full_name IS NULL OR full_name = '') THEN assignee ELSE full_name END),
                    'isActive'   VALUE (CASE WHEN is_active = 'Y' THEN 'true' ELSE 'false' END) FORMAT JSON,
                    'isPending'  VALUE (CASE WHEN is_pending = 'Y' THEN 'true' ELSE 'false' END) FORMAT JSON,
                    'trans'      VALUE (
                        SELECT JSON_ARRAYAGG(
                                 JSON_OBJECT(
                                    'logId'          VALUE c.log_id,
                                    'wfProcessId'    VALUE c.wf_process_id,
                                    'applyName'      VALUE c.apply_name,
                                    'status'         VALUE c.status,
                                    'startTime'      VALUE TO_CHAR(c.start_time, 'YYYY-MM-DD"T"HH24:MI:SS'),
                                    'endTime'        VALUE TO_CHAR(c.end_time, 'YYYY-MM-DD"T"HH24:MI:SS'),
                                    'remarks'        VALUE c.remarks,
                                    'assignee'       VALUE c.assignee,
                                    'approveChannel' VALUE c.approve_channel,
                                    'tranSn'         VALUE c.tran_sn,
                                    'requestId'      VALUE c.request_id,
                                    'userName'       VALUE c.user_name,
                                    'fullName'       VALUE c.full_name,
                                    'isActive'       VALUE (CASE WHEN c.is_active = 'Y' THEN 'true' ELSE 'false' END) FORMAT JSON,
                                    'isPending'      VALUE (CASE WHEN c.is_pending = 'Y' THEN 'true' ELSE 'false' END) FORMAT JSON
                                 ABSENT ON NULL)
                               )
                          FROM TABLE(trans) c
                    ) FORMAT JSON
                 ABSENT ON NULL)
                 ORDER BY rn
               )
          INTO v_json
          FROM (
              SELECT h.*, ROWNUM AS rn
                FROM TABLE(pkg_wf_process_builder.build_process(p_request_id, p_corp_id, p_language, p_service_type)) h
          );

        RETURN NVL(v_json, '[]');

    END build_process_json;

    FUNCTION build_transaction_history_json(
        p_request_id   IN VARCHAR2,
        p_corp_id      IN NUMBER,
        p_language     IN VARCHAR2,
        p_service_type IN VARCHAR2
    ) RETURN CLOB IS
 
        v_days   t_transaction_day_tab;
        v_result CLOB;
 
        -- JSON cho 1 log gốc (phần tử bên trong "trans" của 1 nhóm task)
        FUNCTION child_json(p_c IN t_transaction_child) RETURN CLOB IS
            v CLOB;
        BEGIN
            SELECT JSON_OBJECT(
                     'logId'          VALUE p_c.log_id,
                     'wfProcessId'    VALUE p_c.wf_process_id,
                     'applyName'      VALUE p_c.apply_name,
                     'status'         VALUE p_c.status,
                     'startTime'      VALUE TO_CHAR(p_c.start_time, 'YYYY-MM-DD"T"HH24:MI:SS'),
                     'endTime'        VALUE TO_CHAR(p_c.end_time, 'YYYY-MM-DD"T"HH24:MI:SS'),
                     'remarks'        VALUE p_c.remarks,
                     'assignee'       VALUE p_c.assignee,
                     'approveChannel' VALUE p_c.approve_channel,
                     'tranSn'         VALUE p_c.tran_sn,
                     'requestId'      VALUE p_c.request_id,
                     'userName'       VALUE p_c.user_name,
                     'fullName'       VALUE p_c.full_name,
                     'isActive'       VALUE (CASE WHEN p_c.is_active = 'Y' THEN 'true' ELSE 'false' END) FORMAT JSON,
                     'isPending'      VALUE (CASE WHEN p_c.is_pending = 'Y' THEN 'true' ELSE 'false' END) FORMAT JSON
                   ABSENT ON NULL)
              INTO v
              FROM DUAL;
            RETURN v;
        END child_json;
 
        -- JSON cho 1 leaf (log đơn lẻ HOẶC nhóm task đã gộp), tự lồng "files" và "trans" con
        FUNCTION history_item_json(p_h IN t_transaction_history) RETURN CLOB IS
            v_children CLOB := '[';
            v_files    CLOB := '[';
            v_fileMap  CLOB := '{';
            v          CLOB;
        BEGIN
            IF p_h.trans IS NOT NULL THEN
                FOR i IN 1 .. p_h.trans.COUNT LOOP
                    IF i > 1 THEN
                        v_children := v_children || ',';
                    END IF;
                    v_children := v_children || child_json(p_h.trans(i));
                END LOOP;
            END IF;
            v_children := v_children || ']';
 
            IF p_h.files IS NOT NULL THEN
                FOR i IN 1 .. p_h.files.COUNT LOOP
                    IF i > 1 THEN
                        v_files := v_files || ',';
                        v_fileMap := v_fileMap || ',';
                    END IF;
                    SELECT v_files || JSON_OBJECT(
                             'attachmentId' VALUE p_h.files(i).attachment_id,
                             'fileName'     VALUE p_h.files(i).file_name
                           ABSENT ON NULL)
                      INTO v_files
                      FROM DUAL;
                    v_fileMap := v_fileMap || '"' || p_h.files(i).attachment_id || '"' || ':' || '"' || p_h.files(i).file_name || '"';
                END LOOP;
            END IF;
            v_files := v_files || ']';
            v_fileMap := v_fileMap || '}';
 
            SELECT JSON_OBJECT(
                     'applyName'  VALUE p_h.apply_name,
                     'title'      VALUE p_h.title,
                     'status'     VALUE p_h.status,
                     'startTime'  VALUE TO_CHAR(p_h.start_time, 'YYYY-MM-DD"T"HH24:MI:SS'),
                     'endTime'    VALUE TO_CHAR(p_h.end_time, 'YYYY-MM-DD"T"HH24:MI:SS'),
                     'remarks'    VALUE p_h.remarks,
                     'assignee'   VALUE p_h.assignee,
                     'userName'   VALUE p_h.user_name,
                     'fullName'   VALUE (CASE WHEN (p_h.full_name IS NULL OR p_h.full_name = '')
                                         THEN p_h.assignee ELSE p_h.full_name END),
                     'isActive'   VALUE (CASE WHEN p_h.is_active = 'Y' THEN 'true' ELSE 'false' END) FORMAT JSON,
                     'isPending'  VALUE (CASE WHEN p_h.is_pending = 'Y' THEN 'true' ELSE 'false' END) FORMAT JSON,
                     'files'      VALUE v_files FORMAT JSON,
                     'fileMap'    VALUE v_fileMap FORMAT JSON,
                     'trans'      VALUE v_children FORMAT JSON
                   ABSENT ON NULL)
              INTO v
              FROM DUAL;
            RETURN v;
        END history_item_json;
 
    BEGIN
        SELECT VALUE(t)
          BULK COLLECT INTO v_days
          FROM TABLE(pkg_wf_process_builder.build_transaction_history_by_time(
              p_request_id, p_corp_id, p_language, p_service_type
          )) t;
 
        IF v_days.COUNT = 0 THEN
            RETURN '[]';
        END IF;
 
        v_result := '[';
        FOR d IN 1 .. v_days.COUNT LOOP
            IF d > 1 THEN
                v_result := v_result || ',';
            END IF;
 
            DECLARE
                v_day_children CLOB := '[';
            BEGIN
                IF v_days(d).trans IS NOT NULL THEN
                    FOR h IN 1 .. v_days(d).trans.COUNT LOOP
                        IF h > 1 THEN
                            v_day_children := v_day_children || ',';
                        END IF;
                        v_day_children := v_day_children || history_item_json(v_days(d).trans(h));
                    END LOOP;
                END IF;
                v_day_children := v_day_children || ']';
 
                SELECT v_result || JSON_OBJECT(
                         'time'  VALUE v_days(d).time_key,
                         'trans' VALUE v_day_children FORMAT JSON
                       ABSENT ON NULL)
                  INTO v_result
                  FROM DUAL;
            END;
        END LOOP;
        v_result := v_result || ']';
 
        RETURN v_result;
 
    END build_transaction_history_json;

END pkg_wf_process_builder;
/