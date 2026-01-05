CREATE TABLE ibm_hr_raw (
  Age INT,
  Attrition TEXT,
  BusinessTravel TEXT,
  DailyRate INT,
  Department TEXT,
  DistanceFromHome INT,
  Education INT,
  EducationField TEXT,
  EmployeeCount INT,
  EmployeeNumber INT,
  EnvironmentSatisfaction INT,
  Gender TEXT,
  HourlyRate INT,
  JobInvolvement INT,
  JobLevel INT,
  JobRole TEXT,
  JobSatisfaction INT,
  MaritalStatus TEXT,
  MonthlyIncome INT,
  MonthlyRate INT,
  NumCompaniesWorked INT,
  Over18 TEXT,
  OverTime TEXT,
  PercentSalaryHike INT,
  PerformanceRating INT,
  RelationshipSatisfaction INT,
  StandardHours INT,
  StockOptionLevel INT,
  TotalWorkingYears INT,
  TrainingTimesLastYear INT,
  WorkLifeBalance INT,
  YearsAtCompany INT,
  YearsInCurrentRole INT,
  YearsSinceLastPromotion INT,
  YearsWithCurrManager INT
);

-- Departments
CREATE TABLE departments (
  department_id   SERIAL PRIMARY KEY,
  department_name VARCHAR(100) NOT NULL UNIQUE
);

-- Job roles 
CREATE TABLE job_roles (
  job_id    SERIAL PRIMARY KEY,
  job_title VARCHAR(100) NOT NULL UNIQUE
);

-- Employees (use IBM EmployeeNumber as PK for easy traceability)
CREATE TABLE employees (
  employee_id      INT PRIMARY KEY,
  first_name       VARCHAR(50) NOT NULL,
  last_name        VARCHAR(50) NOT NULL,
  email            VARCHAR(120),
  gender           VARCHAR(20),
  marital_status   VARCHAR(20),
  department_id    INT REFERENCES departments(department_id),
  job_id           INT REFERENCES job_roles(job_id),
  job_level        INT,
  education_field  VARCHAR(100),
  education        INT,
  years_at_company INT,
  monthly_income   INT,
  attrition        VARCHAR(10)   -- 'Yes' / 'No'
);


-- Performance reviews (reviewer_id is synthetic)
CREATE TABLE performance_reviews (
  review_id     SERIAL PRIMARY KEY,
  employee_id   INT REFERENCES employees(employee_id),
  reviewer_id   INT REFERENCES employees(employee_id),
  review_date   DATE NOT NULL,
  review_period VARCHAR(20),
  score         INT,      
  comments      TEXT
);

-- Surveys
CREATE TABLE surveys (
  survey_id   SERIAL PRIMARY KEY,
  survey_type VARCHAR(50) NOT NULL, 
  quarter     INT,
  year        INT
);

-- Survey responses (map IBM satisfaction fields)
CREATE TABLE survey_responses (
  response_id        SERIAL PRIMARY KEY,
  employee_id        INT REFERENCES employees(employee_id),
  survey_id          INT REFERENCES surveys(survey_id),
  engagement_score   INT,   -- EnvironmentSatisfaction
  satisfaction_score INT,   -- JobSatisfaction
  response_date      DATE NOT NULL
);

-- Training programs 
CREATE TABLE training_programs (
  training_id    SERIAL PRIMARY KEY,
  title          VARCHAR(100) NOT NULL,
  topic          VARCHAR(100),
  duration_hours INT
);

-- Employee training 
CREATE TABLE employee_training (
  record_id        SERIAL PRIMARY KEY,
  employee_id      INT REFERENCES employees(employee_id),
  training_id      INT REFERENCES training_programs(training_id),
  enrollment_date  DATE NOT NULL,
  completion_status VARCHAR(20)
);

-- Benefits (lookup)
CREATE TABLE benefits (
  benefit_id   SERIAL PRIMARY KEY,
  benefit_name VARCHAR(100) NOT NULL,
  benefit_type VARCHAR(50),
  description  TEXT
);

-- Employee benefits 
CREATE TABLE employee_benefits (
  record_id       SERIAL PRIMARY KEY,
  employee_id     INT REFERENCES employees(employee_id),
  benefit_id      INT REFERENCES benefits(benefit_id),
  enrollment_date DATE NOT NULL,
  status          VARCHAR(20)
);

-- Departments from IBM
INSERT INTO departments (department_name)
SELECT DISTINCT Department
FROM ibm_hr_raw
WHERE Department IS NOT NULL
ORDER BY Department;

-- Job roles from IBM
INSERT INTO job_roles (job_title)
SELECT DISTINCT JobRole
FROM ibm_hr_raw
WHERE JobRole IS NOT NULL
ORDER BY JobRole;


-- Employees from IBM (simple synthetic names/emails)
INSERT INTO employees (
  employee_id, first_name, last_name, email, gender, marital_status,
  department_id, job_id, job_level, education_field, education,
  years_at_company, monthly_income, attrition
)
SELECT
  r.EmployeeNumber,
  'First' || r.EmployeeNumber,
  'Last'  || r.EmployeeNumber,
  'employee' || r.EmployeeNumber || '@example.com',
  r.Gender,
  r.MaritalStatus,
  d.department_id,
  j.job_id,
  r.JobLevel,
  r.EducationField,
  r.Education,
  r.YearsAtCompany,
  r.MonthlyIncome,
  r.Attrition
FROM ibm_hr_raw r
LEFT JOIN departments d ON d.department_name = r.Department
LEFT JOIN job_roles  j ON j.job_title      = r.JobRole
ORDER BY r.EmployeeNumber;

-- Seed one Engagement survey for the current quarter/year
INSERT INTO surveys (survey_type, quarter, year)
VALUES ('Engagement', EXTRACT(QUARTER FROM CURRENT_DATE)::int, EXTRACT(YEAR FROM CURRENT_DATE)::int);

-- Survey responses from IBM satisfaction fields
INSERT INTO survey_responses (employee_id, survey_id, engagement_score, satisfaction_score, response_date)
SELECT
  r.EmployeeNumber,
  s.survey_id,
  r.EnvironmentSatisfaction,
  r.JobSatisfaction,
  (CURRENT_DATE - (floor(random()*180)::int))::date
FROM ibm_hr_raw r
JOIN employees e ON e.employee_id = r.EmployeeNumber
CROSS JOIN LATERAL (
  SELECT survey_id FROM surveys
  WHERE survey_type = 'Engagement'
    AND quarter = EXTRACT(QUARTER FROM CURRENT_DATE)::int
    AND year    = EXTRACT(YEAR FROM CURRENT_DATE)::int
  LIMIT 1
) s;

-- Performance reviews with manager-as-reviewer logic
INSERT INTO performance_reviews (employee_id, reviewer_id, review_date, review_period, score, comments)
SELECT
  e.employee_id,
  COALESCE(
    (
      SELECT m.employee_id
      FROM employees m
      WHERE m.department_id = e.department_id
        AND m.job_level > e.job_level   -- higher level = manager-like
      ORDER BY random()
      LIMIT 1
    ),
    (
      -- fallback: any colleague in the same department
      SELECT m2.employee_id
      FROM employees m2
      WHERE m2.department_id = e.department_id
      ORDER BY random()
      LIMIT 1
    )
  ) AS reviewer_id,
  CURRENT_DATE,
  TO_CHAR(CURRENT_DATE, 'YYYY') || '-Q' || EXTRACT(QUARTER FROM CURRENT_DATE)::int,
  r.PerformanceRating,
  NULL::text
FROM ibm_hr_raw r
JOIN employees e ON e.employee_id = r.EmployeeNumber;

-- Training programs (simple seed)
INSERT INTO training_programs (title, topic, duration_hours) VALUES
  ('Leadership Skills',       'Leadership',   16),
  ('Technical Certification', 'Technical',    40),
  ('Time Management',         'Productivity',  8);

-- Employee training from IBM TrainingTimesLastYear (explode N rows; random program/dates/status)
WITH exp AS (
  SELECT r.EmployeeNumber AS employee_id,
         GREATEST(COALESCE(r.TrainingTimesLastYear,0), 0) AS n
  FROM ibm_hr_raw r
)
INSERT INTO employee_training (employee_id, training_id, enrollment_date, completion_status)
SELECT
  e.employee_id,
  (SELECT training_id FROM training_programs ORDER BY random() LIMIT 1),
  (CURRENT_DATE - (floor(random()*365)::int))::date,
  (ARRAY['Completed','In Progress','Not Started'])[1 + floor(random()*3)::int]
FROM exp
JOIN employees e ON e.employee_id = exp.employee_id
JOIN LATERAL generate_series(1, exp.n) gs(i) ON TRUE;

-- Benefits (simple seed)
INSERT INTO benefits (benefit_name, benefit_type, description) VALUES
  ('Health Insurance',           'Health',        'Medical coverage.'),
  ('Dental & Vision',            'Health',        'Dental and vision coverage.'),
  ('Retirement Plan (401k)',     'Financial',     '401(k) with company match.'),
  ('Commuter Stipend',           'Transportation','Transit/parking stipend.'),
  ('Gym Membership',             'Wellness',      'Subsidized gym access.');

-- Employee benefits (1–3 random benefits/employee; random dates; mostly Active)
WITH emp AS (
  SELECT employee_id FROM employees
),
pairs AS (
  SELECT e.employee_id, (1 + floor(random()*3)::int) AS n_bens
  FROM emp e
),
expanded AS (
  SELECT
    p.employee_id,
    (SELECT benefit_id FROM benefits ORDER BY random() LIMIT 1) AS benefit_id,
    (CURRENT_DATE - (floor(random()*1460)::int))::date          AS enrollment_date,
    CASE WHEN random() < 0.85 THEN 'Active' ELSE 'Cancelled' END AS status
  FROM pairs p
  JOIN LATERAL generate_series(1, p.n_bens) gs(i) ON TRUE
)
INSERT INTO employee_benefits (employee_id, benefit_id, enrollment_date, status)
SELECT employee_id, benefit_id, enrollment_date, status
FROM expanded;

WITH
  fn_f AS (
    SELECT ARRAY[
      'Emma','Olivia','Sophia','Ava','Isabella','Mia','Amelia','Harper','Evelyn','Abigail',
      'Ella','Scarlett','Chloe','Grace','Lily','Victoria','Hannah','Zoe','Nora','Aria',
      'Layla','Penelope','Riley','Zoey','Nora','Lillian','Addison','Aubrey','Brooklyn','Paisley'
    ] AS arr
  ),
  fn_m AS (
    SELECT ARRAY[
      'Liam','Noah','Oliver','Elijah','James','William','Benjamin','Lucas','Henry','Alexander',
      'Michael','Daniel','Matthew','Jackson','Samuel','David','Joseph','Carter','Owen','Wyatt',
      'John','Jack','Luke','Levi','Gabriel','Julian','Dylan','Isaac','Anthony','Andrew'
    ] AS arr
  ),
  fn_u AS (
    -- neutral / unisex fallback
    SELECT ARRAY[
      'Alex','Taylor','Jordan','Casey','Riley','Quinn','Morgan','Rowan','Reese','Dakota',
      'Parker','Cameron','Avery','Charlie','Elliot','Jamie','Skyler','Emerson','Hayden','Sage'
    ] AS arr
  ),
  ln AS (
    SELECT ARRAY[
      'Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis','Rodriguez','Martinez',
      'Hernandez','Lopez','Gonzalez','Wilson','Anderson','Thomas','Taylor','Moore','Jackson','Martin',
      'Lee','Perez','Thompson','White','Harris','Sanchez','Clark','Ramirez','Lewis','Robinson',
      'Walker','Young','Allen','King','Wright','Scott','Torres','Nguyen','Hill','Flores'
    ] AS arr
  ),
  counts AS (
    SELECT
      array_length((SELECT arr FROM fn_f),1) AS n_f,
      array_length((SELECT arr FROM fn_m),1) AS n_m,
      array_length((SELECT arr FROM fn_u),1) AS n_u,
      array_length((SELECT arr FROM ln  ),1) AS n_ln
  ),
  mapped AS (
    SELECT
      e.employee_id,
      -- choose gender bucket
      CASE
        WHEN e.gender ILIKE 'Female' THEN 'F'
        WHEN e.gender ILIKE 'Male'   THEN 'M'
        ELSE 'U'
      END AS g,
      -- deterministic indexes (1-based) using employee_id
      1 + ((e.employee_id - 1) % (SELECT n_f FROM counts)) AS idx_f,
      1 + ((e.employee_id - 1) % (SELECT n_m FROM counts)) AS idx_m,
      1 + ((e.employee_id - 1) % (SELECT n_u FROM counts)) AS idx_u,
      1 + ((e.employee_id - 1) % (SELECT n_ln FROM counts)) AS idx_ln
    FROM employees e
    -- Limit to obvious placeholders; remove this WHERE to overwrite everyone
    WHERE (e.first_name ILIKE 'First%' OR e.last_name ILIKE 'Last%')
  ),
  chosen AS (
    SELECT
      m.employee_id,
      -- pick first name from the right array by gender
      CASE m.g
        WHEN 'F' THEN (SELECT (SELECT arr FROM fn_f)[m.idx_f])
        WHEN 'M' THEN (SELECT (SELECT arr FROM fn_m)[m.idx_m])
        ELSE          (SELECT (SELECT arr FROM fn_u)[m.idx_u])
      END AS new_first,
      -- pick last name
      (SELECT (SELECT arr FROM ln)[m.idx_ln]) AS new_last
    FROM mapped m
  )
UPDATE employees e
SET first_name = c.new_first,
    last_name  = c.new_last,
    email      = lower(
                   regexp_replace(c.new_first,'[^a-zA-Z]','','g') || '.' ||
                   regexp_replace(c.new_last ,'[^a-zA-Z]','','g') ||
                   e.employee_id || '@example.com'
                 )
FROM chosen c
WHERE e.employee_id = c.employee_id;

UPDATE employees e
SET job_id = jr.job_id
FROM job_roles jr
JOIN ibm_hr_raw r ON r.JobRole = jr.job_title
WHERE e.employee_id = r.EmployeeNumber
  AND e.job_id IS NULL;

WITH params AS (
  SELECT date_trunc('month', CURRENT_DATE) - INTERVAL '18 months' AS start_month,
         date_trunc('month', CURRENT_DATE)                         AS end_month
),
months AS (
  SELECT generate_series(
           (SELECT start_month FROM params)::date,
           (SELECT end_month   FROM params)::date,
           interval '1 month'
         )::date AS month_start
),
candidate_months AS (
  -- Build (employee_id x months) grid and sample 2–4 months per employee
  SELECT e.employee_id,
         m.month_start
  FROM employees e
  CROSS JOIN months m
),
sampled AS (
  -- Pick 2–4 random months per employee deterministically per run
  SELECT employee_id, month_start
  FROM (
    SELECT c.*,
           ROW_NUMBER() OVER (
             PARTITION BY c.employee_id ORDER BY random()
           ) AS rn,
           -- decide how many months to keep for this employee (2–4)
           (2 + FLOOR(random() * 3))::int AS keep_n
    FROM candidate_months c
  ) s
  WHERE rn <= keep_n
),
reviewer_choice AS (
  -- For each employee, pick a reviewer in the same department, preferring higher job_level
  SELECT e.employee_id,
         COALESCE(
           (
             SELECT e_mgr.employee_id
             FROM employees e_mgr
             WHERE e_mgr.department_id = e.department_id
               AND e_mgr.employee_id <> e.employee_id
               AND e_mgr.job_level    > e.job_level
             ORDER BY random()
             LIMIT 1
           ),
           (
             SELECT e_peer.employee_id
             FROM employees e_peer
             WHERE e_peer.department_id = e.department_id
               AND e_peer.employee_id <> e.employee_id
             ORDER BY random()
             LIMIT 1
           )
         ) AS reviewer_id
  FROM employees e
),
to_insert AS (
  -- Build rows to insert (skip if same employee already has a review in that month)
  SELECT s.employee_id,
         r.reviewer_id,
         -- random day within the chosen month (1..28 for safety)
         (s.month_start + ((FLOOR(random()*28))::int || ' days')::interval)::date AS review_date,
         to_char(s.month_start, 'YYYY-MM') AS review_period,
         -- integer score 1..5 (you can make this more sophisticated if you like)
         (1 + FLOOR(random()*5))::int AS score,
         'Auto-generated review'::text AS comments
  FROM sampled s
  JOIN reviewer_choice r USING (employee_id)
  WHERE NOT EXISTS (
    SELECT 1
    FROM performance_reviews pr
    WHERE pr.employee_id = s.employee_id
      AND date_trunc('month', pr.review_date) = s.month_start
  )
)
INSERT INTO performance_reviews (employee_id, reviewer_id, review_date, review_period, score, comments)
SELECT employee_id, reviewer_id, review_date, review_period, score, comments
FROM to_insert;
 