-- ======================================================
-- HR Employee Experience - Query Examples (15) WITH EXPLANATIONS
-- Schema: departments, job_roles, employees, performance_reviews,
--         surveys, survey_responses, training_programs,
--         employee_training, benefits, employee_benefits
-- Each query includes: purpose, business value, expected result description.
-- ======================================================

-- Q1) Latest performance review per employee (JOIN + correlated subquery)
-- Purpose: Show each employee’s most recent review score and date.
-- Business value: Managers can quickly see current performance status for talent reviews.
-- Expected result: One row per employee with department, latest review_date, and score.
SELECT e.employee_id,
       e.first_name || ' ' || e.last_name AS full_name,
       d.department_name,
       pr.review_date,
       pr.score
FROM employees e
JOIN departments d ON d.department_id = e.department_id
JOIN performance_reviews pr
  ON pr.employee_id = e.employee_id
WHERE pr.review_date = (
  SELECT MAX(pr2.review_date)
  FROM performance_reviews pr2
  WHERE pr2.employee_id = e.employee_id
)
ORDER BY d.department_name, full_name;

-- Q2) Rank departments by average engagement (AGG + WINDOW RANK)
-- Purpose: Compute department engagement averages and rank them.
-- Business value: Identify teams that need engagement interventions.
-- Expected result: One row per department with avg_engagement and rank (1 = highest).
WITH dept_avg AS (
  SELECT d.department_name,
         AVG(sr.engagement_score)::NUMERIC(4,2) AS avg_engagement
  FROM departments d
  JOIN employees e ON e.department_id = d.department_id
  JOIN survey_responses sr ON sr.employee_id = e.employee_id
  GROUP BY d.department_name
)
SELECT department_name,
       avg_engagement,
       RANK() OVER (ORDER BY avg_engagement DESC) AS engagement_rank
FROM dept_avg
ORDER BY engagement_rank;

-- Q3) Engagement by tenure band and role (CASE + GROUP BY)
-- Purpose: Compare engagement across tenure cohorts within each role.
-- Business value: Tailor onboarding and retention programs to tenure stage.
-- Expected result: For each job_title and tenure_band, average engagement and count of responses.
SELECT jr.job_title,
       CASE
         WHEN e.years_at_company < 2 THEN '0-1'
         WHEN e.years_at_company < 5 THEN '2-4'
         ELSE '5+'
       END AS tenure_band,
       AVG(sr.engagement_score)::NUMERIC(4,2) AS avg_engagement,
       COUNT(*) AS responses
FROM employees e
JOIN job_roles jr ON jr.job_id = e.job_id
JOIN survey_responses sr ON sr.employee_id = e.employee_id
GROUP BY jr.job_title, tenure_band
ORDER BY jr.job_title, tenure_band;

-- Q4) Employees below their department average performance (SUBQUERY)
-- Purpose: Flag employees scoring below their department’s mean.
-- Business value: Targeted coaching and performance conversations.
-- Expected result: Employee list with department and their score (< dept avg).
SELECT e.employee_id,
       e.first_name || ' ' || e.last_name AS full_name,
       d.department_name,
       pr.score
FROM performance_reviews pr
JOIN employees e ON e.employee_id = pr.employee_id
JOIN departments d ON d.department_id = e.department_id
WHERE pr.score < (
  SELECT AVG(pr2.score)
  FROM performance_reviews pr2
  JOIN employees e2 ON e2.employee_id = pr2.employee_id
  WHERE e2.department_id = e.department_id
);

-- Q5) Survey responders without a performance review (SET OP: EXCEPT)
-- Purpose: Data/process coverage gap.
-- Business value: Ensure review compliance.
-- Expected result: Employee IDs present in surveys but missing in reviews.
SELECT sr.employee_id
FROM survey_responses sr
EXCEPT
SELECT pr.employee_id
FROM performance_reviews pr;

-- Q6) Running average engagement per employee (WINDOW)
-- Purpose: Track how engagement evolves over time per employee.
-- Business value: Early detection of declines for intervention.
-- Expected result: One row per response with running average up to that date.
SELECT e.employee_id,
       sr.response_date,
       sr.engagement_score,
       AVG(sr.engagement_score) OVER (
         PARTITION BY e.employee_id
         ORDER BY sr.response_date
         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       )::NUMERIC(4,2) AS running_avg_engagement
FROM employees e
JOIN survey_responses sr ON sr.employee_id = e.employee_id
ORDER BY e.employee_id, sr.response_date;

-- Q7) Training participation vs average performance (AGG + JOIN)
-- Purpose: Examine association between training volume and performance.
-- Business value: Inform L&D investment decisions.
-- Expected result: For employees with training, show training count and their avg performance score.
WITH perf AS (
  SELECT pr.employee_id, AVG(pr.score) AS avg_score
  FROM performance_reviews pr
  GROUP BY pr.employee_id
),
train AS (
  SELECT et.employee_id, COUNT(*) AS trainings
  FROM employee_training et
  GROUP BY et.employee_id
)
SELECT t.employee_id, t.trainings, p.avg_score::NUMERIC(4,2) AS avg_score
FROM train t
LEFT JOIN perf p ON p.employee_id = t.employee_id
ORDER BY trainings DESC, avg_score DESC;

-- Q8) Top 5 training programs by enrollment (AGG + ORDER)
-- Purpose: Find most popular programs.
-- Business value: Prioritize budget and scheduling.
-- Expected result: Program titles with enrollment counts, top 5.
SELECT tp.title,
       COUNT(et.record_id) AS enrollments
FROM training_programs tp
LEFT JOIN employee_training et ON et.training_id = tp.training_id
GROUP BY tp.title
ORDER BY enrollments DESC, tp.title
LIMIT 5;

-- Q9) Benefit adoption and active rate (AGG + CASE)
-- Purpose: Measure usage and activation of benefits.
-- Business value: Optimize benefits portfolio and vendor spend.
-- Expected result: One row per benefit with total, active count, and % active.
SELECT b.benefit_name,
       COUNT(eb.record_id) AS total_enrollments,
       SUM(CASE WHEN eb.status = 'Active' THEN 1 ELSE 0 END) AS active_enrollments,
       ROUND(100.0 * SUM(CASE WHEN eb.status = 'Active' THEN 1 ELSE 0 END) / NULLIF(COUNT(eb.record_id),0), 2) AS active_pct
FROM benefits b
LEFT JOIN employee_benefits eb ON eb.benefit_id = b.benefit_id
GROUP BY b.benefit_name
ORDER BY total_enrollments DESC;

-- Q10) Attrition rate by department (AGG + CASE)
-- Purpose: Quantify attrition hotspots.
-- Business value: Focus retention strategies where they matter.
-- Expected result: Department, leavers, headcount, and percent attrition.
SELECT d.department_name,
       SUM(CASE WHEN e.attrition = 'Yes' THEN 1 ELSE 0 END) AS leavers,
       COUNT(*) AS headcount,
       ROUND(100.0 * SUM(CASE WHEN e.attrition = 'Yes' THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0), 2) AS attrition_pct
FROM employees e
JOIN departments d ON d.department_id = e.department_id
GROUP BY d.department_name
ORDER BY attrition_pct DESC;

-- Q11) Performance score distribution with totals (ROLLUP)
-- Purpose: Histogram of scores with an overall total row.
-- Business value: Snapshot of performance calibration.
-- Expected result: Rows for each score and an 'ALL' total row.
SELECT COALESCE(CAST(score AS TEXT),'ALL') AS score_bucket,
       COUNT(*) AS cnt
FROM performance_reviews
GROUP BY ROLLUP (score)
ORDER BY CASE WHEN score_bucket = 'ALL' THEN 1 ELSE 0 END, score_bucket;

-- Q12) Monthly average performance trend (DATE_TRUNC)
-- Purpose: Show monthly performance trend.
-- Business value: Detect seasonality or policy impact.
-- Expected result: One row per month with avg score and review count.
SELECT DATE_TRUNC('month', review_date)::DATE AS month,
       AVG(score)::NUMERIC(4,2) AS avg_score,
       COUNT(*) AS reviews
FROM performance_reviews
GROUP BY 1
ORDER BY 1;

-- Q13) Reviewer effectiveness (SUBQ + WINDOW)
-- Purpose: Compare reviewers' own latest score to their reviewees' average score.
-- Business value: Proxy signal for coaching quality or calibration.
-- Expected result: One row per reviewer with their latest score and team average.
WITH latest_reviewer_score AS (
  SELECT pr.employee_id AS reviewer_id,
         pr.score,
         ROW_NUMBER() OVER (PARTITION BY pr.employee_id ORDER BY pr.review_date DESC) AS rn
  FROM performance_reviews pr
),
team_avg AS (
  SELECT pr.reviewer_id,
         AVG(pr.score) AS team_avg_score
  FROM performance_reviews pr
  WHERE pr.reviewer_id IS NOT NULL
  GROUP BY pr.reviewer_id
)
SELECT t.reviewer_id,
       r.score AS reviewer_latest_score,
       t.team_avg_score::NUMERIC(4,2)
FROM team_avg t
LEFT JOIN latest_reviewer_score r ON r.reviewer_id = t.reviewer_id AND r.rn = 1
ORDER BY t.team_avg_score DESC NULLS LAST;

-- Q14) Employees with no training in the last 365 days (NOT EXISTS + DATE)
-- Purpose: Identify people due for training outreach.
-- Business value: Improve learning culture and compliance.
-- Expected result: Employee list (id, name, department) missing recent training.
SELECT e.employee_id,
       e.first_name || ' ' || e.last_name AS full_name,
       d.department_name
FROM employees e
JOIN departments d ON d.department_id = e.department_id
WHERE NOT EXISTS (
  SELECT 1
  FROM employee_training et
  WHERE et.employee_id = e.employee_id
    AND et.enrollment_date >= CURRENT_DATE - INTERVAL '365 days'
);

-- Q15) Combined engagement & satisfaction KPI by department (multi-AGG)
-- Purpose: Balanced sentiment KPI for leadership dashboard.
-- Business value: Single view to track morale and satisfaction.
-- Expected result: One row per department with two KPIs and response count.
SELECT d.department_name,
       AVG(sr.engagement_score)::NUMERIC(4,2)   AS avg_engagement,
       AVG(sr.satisfaction_score)::NUMERIC(4,2) AS avg_satisfaction,
       COUNT(*) AS responses
FROM departments d
JOIN employees e ON e.department_id = d.department_id
JOIN survey_responses sr ON sr.employee_id = e.employee_id
GROUP BY d.department_name
ORDER BY avg_engagement DESC, avg_satisfaction DESC;
