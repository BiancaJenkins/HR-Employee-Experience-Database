# HR Employee Experience Database/Analytics Capstone

This project is a graduate capstone for **DTSC 691 – Applied Data Science**. It demonstrates the design, implementation, and analysis of a relational **HR analytics database** used to explore employee experience, performance, training, engagement, and attrition.

The project integrates **PostgreSQL**, **advanced SQL**, and **Python-based analysis and visualization** to replicate real-world People Analytics workflows.

---

## 📌 Project Objectives
- Design a realistic, normalized HR database schema (8+ tables)
- Integrate real-world and synthetic HR data
- Demonstrate advanced SQL querying for business insights
- Perform exploratory and statistical analysis using Python
- Visualize workforce trends to support data-driven HR decisions

---

## 🧠 Problem Domain
Human Resources / People Analytics  
Focus areas include:
- Employee engagement and satisfaction
- Performance reviews and trends
- Training participation
- Benefits utilization
- Attrition and retention risk

---

## 🗂️ Database Schema
The PostgreSQL schema includes the following core tables:

- `employees`
- `departments`
- `job_roles`
- `performance_reviews`
- `surveys`
- `survey_responses`
- `training_programs`
- `employee_training`
- `benefits`
- `employee_benefits`

Synthetic data was generated to supplement the IBM HR Analytics dataset for attributes not originally available (e.g., names, performance reviews, benefits enrollment).

---

## 🛠️ Technologies Used
- **Database:** PostgreSQL, pgAdmin
- **Query Language:** SQL (DDL & DML)
- **Analysis:** Python (pandas, numpy)
- **Visualization:** matplotlib
- **Environment:** Jupyter Notebook
- **Data Sources:** IBM HR Analytics dataset + synthetic data (SQL-based seeding)

---

## 🔍 SQL Query Highlights
The project includes **15+ advanced SQL queries**, showcasing:
- INNER, LEFT, and SELF JOINs
- Subqueries and set operations
- Aggregations and grouping
- CASE statements
- Window functions (RANK, running averages)
- ROLLUP and date-based analysis

These queries answer key HR questions such as:
- Which departments have the highest attrition?
- How does engagement vary by tenure and role?
- Does training participation correlate with performance?
- How has performance trended over time?

---

## 📊 Python Integration & Analysis
The PostgreSQL database is integrated into Python using SQLAlchemy and pandas. Analysis includes:
- Descriptive statistics (means, distributions)
- Correlation analysis between engagement, performance, and attrition
- Time-series analysis of performance trends
- Workforce KPIs by department

---

## 📈 Visualizations
Key visual outputs include:
- Attrition rate by department
- Salary and tenure distributions
- Monthly performance trends
- Engagement and satisfaction comparisons

All visuals are generated programmatically and included in the analysis notebook.
