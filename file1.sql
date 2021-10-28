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


CREATE OR REPLACE FUNCTION grade_uploading(
    IN course_id varchar(10),
    IN file_path varchar(1000)
) RETURN VOID AS $$
DECLARE
    course_entry RECORD,
    current_course_iterator RECORD,
    store_data_temp RECORD
    result varchar(15)

BEGIN
    CREATE TABLE student_grade(
        entry_number varchar(15),
        grade int
    );

    COPY student_grade FROM file_path WITH (FORMAT csv);
    -- agr ye na chale to
    -- \copy student_grade FROM file_path DELIMITER ',' CSV;

    FOR course_entry IN student_grade
    LOOP
        FOR current_course_iterator IN 
        EXECUTE format('student_current_courses_%I',course_entry.entry_number)
        LOOP
            IF current_course_iterator.course_id = course_id THEN
                store_data_temp = current_course_iterator;
                exit;
            END IF;
        END LOOP;

        IF course_entry.grade < 5 THEN
            result = 'Failed';
        ELSE
            result = 'Completed'
        END IF;

        EXECUTE format(
            'INSERT INTO %I VALUES(%L,%L,%L,%L,%L,%L);', 'student_past_courses_' || course_entry.entry_number, store_data_temp.faculty_id, store_data_temp.course_id, store_data_temp.year, store_data_temp.semester, result, course_entry.grade
        );

        EXECUTE format('DELETE FROM %I WHERE course_id = course_id;','student_current_courses_' || course_entry.entry_number)
       

    END LOOP;

END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION report_generation(
    IN entry_number varchar(15),
    IN required_semester int,
    IN required_year int,
    OUT student_entry_number varchar(15),
    OUT student_name varchar(200),
    OUT report_semester int,
    OUT report_year int,
    OUT credits_completed int,
    OUT sgpa int,
    OUT cgpa int
) RETURN void AS $$
DECLARE
    course_entry RECORD,
    temp_credits int,
    report_entry RECORD,
    sgpa_numerator int

BEGIN
    student_entry_number = entry_number;
    student_name = SELECT concat(first_name,' ',last_name) FROM student_database WHERE entry_number = student_entry_number;
    report_semester = required_semester;
    report_year = required_year;
    credits_completed = 0;

    CREATE TABLE student_report(
        course_id varchar(10),
        grade int,
        credits int
    );

    FOR course_entry IN
    EXECUTE format('student_past_courses_%I',entry_number)
    LOOP
        IF course_entry.semester=required_semester AND course_entry.year=required_year THEN

            temp_credits=0;

            IF course_entry.grade > 5 THEN
                temp_credits = SELECT credits FROM course_catalog WHERE course_id=course_entry.course_id;
                credits_completed = credits_completed + temp_credits;
            END IF;

            EXECUTE format(
                'INSERT INTO student_report VALUES(%L, %L, %L);', course_entry.course_id, course_entry.grade, temp_credits
            );

        END IF; 
    END LOOP;

    sgpa_numerator=0;

    FOR report_entry IN student_report
    LOOP
        sgpa_numerator = sgpa_numerator + report_entry.credits * report_entry.grade;
    END LOOP;

    sgpa = sgpa_numerator / credits_completed;

    --cgpa store me se uthani h
END 
$$ LANGUAGE plpgsql;