-- ======================================================
-- Parameterized Variants (via a params CTE) for reuse in demos
-- Change values in the params CTE to slice by quarter/year and dates.
-- ======================================================

WITH params AS (
  SELECT
    EXTRACT(YEAR FROM CURRENT_DATE)::INT AS year_val,
    EXTRACT(QUARTER FROM CURRENT_DATE)::INT AS qtr_val,
    (CURRENT_DATE - INTERVAL '365 days')::DATE AS since_date
)
-- Example A: Engagement only for the current quarter/year from params
SELECT d.department_name,
       AVG(sr.engagement_score)::NUMERIC(4,2) AS avg_engagement_qtr
FROM departments d
JOIN employees e ON e.department_id = d.department_id
JOIN survey_responses sr ON sr.employee_id = e.employee_id
JOIN surveys s ON s.survey_id = sr.survey_id
CROSS JOIN params p
WHERE s.year = p.year_val AND s.quarter = p.qtr_val
GROUP BY d.department_name
ORDER BY avg_engagement_qtr DESC;

WITH params AS (
  SELECT (CURRENT_DATE - INTERVAL '365 days')::DATE AS since_date
)
-- Example B: No-training-since params.since_date
SELECT e.employee_id, e.first_name || ' ' || e.last_name AS full_name, d.department_name
FROM employees e
JOIN departments d ON d.department_id = e.department_id
CROSS JOIN params p
WHERE NOT EXISTS (
  SELECT 1 FROM employee_training et
  WHERE et.employee_id = e.employee_id
    AND et.enrollment_date >= p.since_date
);
