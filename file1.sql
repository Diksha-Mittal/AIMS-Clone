CREATE OR REPLACE TABLE timetables (
    day varchar(10),
    beginning time,
    ending time,
    id int
);

CREATE TABLE student_database(
    first_name varchar(100),
    last_name varchar(100),
    entry_number varchar(15),
    batch varchar(100),
    degree_start_year int,
    branch varchar(100),
    credits_completed int
);

CREATE TABLE faculty_database(
    first_name varchar(100),
    last_name varchar(100),
    faculty_id varchar(15),
    department varchar(100)
);

CREATE TABLE batchwise_fa_list(
    batch varchar(100),
    degree_start_year int,
    branch varchar(100),
    faculty_id varchar(15)
);

CREATE OR REPLACE FUNCTION student_ticket_generator(
    IN entry_number varchar(15),
    IN extra_credits_required int,
    IN semester int,
    IN curryear int
) RETURN VOID AS $$
BEGIN
    -- add ticket to student ticket table
    EXECUTE format(
        'INSERT INTO %I VALUES(%I,%I,%I,%I,Awaiting FA Approval);', 'student_ticket_table_' || entry_number, entry_number || '_' || semester || '_' || curryear, extra_credits_required, semester, curryear
    );

    faculty_id := 
        SELECT l.faculty_id 
        FROM student_database s, batchwise_fa_list l
        WHERE s.entry_number=entry_number and l.batch=s.batch and l.degree_start_year=s.degree_start_year and l.branch=s.branch;

    -- add ticket to FA's table
    EXECUTE format(
        'INSERT INTO %I VALUES(%I,%I,%I,Awaiting Approval);', 'advisor_ticket_table_' || faculty_id, entry_number || '_' || semester || '_' || curryear, entry_number, extra_credits_required
    );
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fa_acceptance(
    IN ticket_id varchar(100),
    IN entry_number varchar(15)
) RETURN VOID AS $$
BEGIN
    -- update status in student ticket table
    EXECUTE format(
        'UPDATE %I 
         SET status="Awaiting dean approval"
         WHERE ticket_id=%I;', 'student_ticket_table_' || entry_number, ticket_id
    );

    -- update status in FAs ticket table
    faculty_id = SELECT CURRENT_USER;
    EXECUTE format(
        'UPDATE %I 
         SET status="Approved"
         WHERE ticket_id=%I;', 'advisor_ticket_table_' || faculty_id, ticket_id
    );

    --update status in dean's ticket table
    EXECUTE format(
        'extra_credits_required :=
            SELECT stt.extra_credits_required
            FROM %I stt
            WHERE stt.ticket_id=ticket_id;
        INSERT INTO dean_ticket_table VALUES(%I,%I,%I,Awaiting Approval);', 'student_ticket_table_' || entry_number, ticket_id, entry_number, extra_credits_required
    );
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fa_rejection(
    IN ticket_id varchar(100),
    IN entry_number varchar(15)
) RETURN VOID AS $$
BEGIN
    -- update status in student ticket table
    EXECUTE format(
        'UPDATE %I 
         SET status="Rejected by FA"
         WHERE ticket_id=%I;', 'student_ticket_table_' || entry_number, ticket_id
    );

    -- update status in FAs ticket table
    faculty_id = SELECT CURRENT_USER;
    EXECUTE format(
        'UPDATE %I 
         SET status="Rejected"
         WHERE ticket_id=%I;', 'advisor_ticket_table_' || faculty_id, ticket_id
    );
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION dean_acceptance(
    IN ticket_id varchar(100),
    IN entry_number varchar(15)
) RETURN VOID AS $$
BEGIN
    -- update status in student ticket table
    EXECUTE format(
        'UPDATE %I 
         SET status="Approved"
         WHERE ticket_id=%I;', 'student_ticket_table_' || entry_number, ticket_id
    );

    -- update status in dean's table
    EXECUTE format(
        'UPDATE dean_ticket_table
         SET status="Approved"
         WHERE ticket_id=%I;', ticket_id
    );

    -- update max credit limit for the student

END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION dean_rejection(
    IN ticket_id varchar(100),
    IN entry_number varchar(15)
) RETURN VOID AS $$
BEGIN
    -- update status in student ticket table
    EXECUTE format(
        'UPDATE %I 
         SET status="Rejected by dean"
         WHERE ticket_id=%I;', 'student_ticket_table_' || entry_number, ticket_id
    );

    -- update status in dean's table
    EXECUTE format(
        'UPDATE dean_ticket_table
         SET status="Rejected"
         WHERE ticket_id=%I;', ticket_id
    );
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION report_generation(
    IN entry_number varchar(15),
    IN semester int,
    IN curryear int
) RETURN VOID AS $$
BEGIN

END
$$ LANGUAGE plpgsql;