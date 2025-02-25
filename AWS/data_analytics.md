# Data analytics Overview 
---

## 1. Architecture Diagram with Phases

``` 
                    [ PHASE 1: Data Ingestion ]                   
                         +-----------------------------------+
                         |   On-Prem & External Sources       |
                         | (Databases, Files, APIs, SaaS Apps)|
                         +--------------------+----------------+
                                           |
     +----------------------------------------------------------------------+
     |        Ingestion Tools (Batch, Real-time, Offline)                   |
     | - AWS DMS / Qlik Replicate (CDC from DBs)                            |
     | - AWS DataSync (File transfers)                                      |
     | - AWS Transfer Family (FTP/SFTP)                                     |
     | - Amazon Kinesis (Data Streams/Firehose for streaming)               |
     | - AWS Snowball / Snowmobile (offline bulk data transfer)             |
     +-------------------------+--------------------------------------------+
                                   |
                                   v
          [ PHASE 2: Raw Data Landing & Storage (Data Lake on Amazon S3) ]
                +-------------------------------------------------------+
                |         Amazon S3 (Raw, Unstructured, Semi-structured)|
                +--------------------------+------------------------------+
                                   |         
                                   |  [Optional: Data Catalog / Metadata]
                                   v
                   [ PHASE 3: Data Transformation (ETL or ELT) ]
                       +---------------------------------------------+
                       |  AWS Glue, Qlik Compose, Talend, Informatica|
                       |  (Clean, Enrich, Partition, Catalog Data)   |
                       +----------------------+------------------------+
                                          |
                                          | [Transformed Data]             
                                          v
                [ PHASE 4: Data Warehouse (for Analytics / BI / Reporting) ]
                           +----------------------------------------------+
                           |   Amazon Redshift, Snowflake on AWS, etc.    |
                           | (Schema-on-write, OLAP-optimized)            |
                           +----------------------+------------------------+
                                          |
                                          v
          [ PHASE 5: Analytics, Visualization, & ML/AI Consumption ]
         +-----------------------------------------------------------------+
         |   - Qlik Sense / QlikView, Tableau, Power BI, Amazon QuickSight |
         |   - AWS SageMaker (ML model building)                           |
         |   - Amazon EMR / Spark (Big data processing)                    |
         +-----------------------------------------------------------------+
```

### Phase Breakdown

1. **Phase 1: Data Ingestion**  
   - **Objective**: Collect data from various on-premises or external sources.  
   - **Tools**:  
     - **AWS DMS** or **Qlik Replicate** for capturing changes (CDC) in near-real-time from relational databases.  
     - **AWS DataSync** or **AWS Transfer Family** for file-based ingestion.  
     - **Amazon Kinesis** (Data Streams or Firehose) for streaming data (log files, clickstreams, IoT data).  
     - **AWS Snowball** or **Snowmobile** for large-scale, offline data migration (TB–PB).

2. **Phase 2: Raw Data Landing & Storage (Data Lake on Amazon S3)**  
   - **Objective**: Store all ingested data “as-is” (structured, semi-structured, unstructured) at low cost and high durability.  
   - **AWS Service**: **Amazon S3** acts as the **raw data repository** (data lake).  
   - **Benefits**:  
     - Decouples storage from compute.  
     - Stores unlimited volumes of data in its native format.  
     - Enables downstream transformations and analytics at scale.

3. **Phase 3: Data Transformation (ETL/ELT)**  
   - **Objective**: Transform raw data into curated or enriched datasets, often partitioned and optimized for analytics.  
   - **Approach**:  
     - **ETL (Extract, Transform, Load)**: Transform data **before** loading into the data warehouse.  
     - **ELT (Extract, Load, Transform)**: Load raw data into the warehouse first, then transform **inside** the warehouse.  
   - **Tools**:  
     - **AWS Glue** (native AWS service) for serverless ETL, schema discovery, and data cataloging.  
     - **Qlik Compose** (part of Qlik’s data integration suite), **Talend**, **Informatica**, etc. for advanced data integration, data quality, and automation.  
   - **Outcome**:  
     - Cleaned, enriched, or aggregated data sets, typically stored back in S3 (curated zone) or loaded directly into the data warehouse.

4. **Phase 4: Data Warehouse**  
   - **Objective**: Provide a structured, high-performance environment for analytic queries (OLAP) and business reporting.  
   - **Common Choices**:  
     - **Amazon Redshift**: Scalable, MPP, columnar database optimized for analytical workloads.  
     - **Snowflake** on AWS: A multi-cloud data warehouse with automatic scaling and separation of storage/compute.  
   - **Data Flow**:  
     - Transformed/optimized data from Phase 3 is **loaded** (via ETL/ELT jobs) into the warehouse.  
     - The warehouse often contains **dimensional schemas** (star/snowflake) for faster BI queries.

5. **Phase 5: Analytics, Visualization & ML/AI Consumption**  
   - **Objective**: End-users and data teams derive insights, build dashboards, and perform advanced analytics or machine learning.  
   - **BI & Visualization Tools**:  
     - **Qlik Sense / QlikView**, **Tableau**, **Power BI**, **Amazon QuickSight** for interactive dashboards and reports.  
   - **Machine Learning**:  
     - **AWS SageMaker** for building/training ML models at scale.  
     - **Amazon EMR** (Spark, Hadoop, Hive) for big data processing and AI frameworks.  
     - **Qlik AutoML** (if using the Qlik ecosystem) for automated machine learning.

---

## 2. How Raw Data Moves from S3 to the Data Warehouse

1. **Data Landing in Amazon S3**:  
   - Ingested data is first **copied or streamed** into a raw bucket (e.g., *s3://my-data-lake/raw/*).  
   - This “raw zone” is typically an immutable source of truth.

2. **Transformation (ETL/ELT)**:  
   - A **job** (scheduled or on-demand) in **AWS Glue** or **Qlik Compose** (or another tool) **reads** the raw data from S3.  
   - It performs **data cleansing** (e.g., removing duplicates, normalizing fields), **format conversions** (CSV → Parquet), **partitioning**, and **enrichment** (e.g., adding reference data).  
   - Depending on your approach:  
     - **ETL**: The data is **transformed** on ephemeral compute (Glue/Spark, Qlik Compose engine) and **then** loaded into the warehouse.  
     - **ELT**: The raw data is **loaded** into the warehouse first, and transformations happen **within** the warehouse (using SQL scripts, stored procedures, or external transformations).

3. **Loading into the Data Warehouse**:  
   - For **Amazon Redshift**, you might use the **COPY** command to bulk load data from S3 directly into Redshift tables.  
   - For **Snowflake**, you can use **Snowpipe** or the **COPY** into command to ingest data from S3.  
   - Tools like **Qlik Compose** can automate the entire load and schema mapping process.

---

## 3. ETL vs. ELT: Key Points

- **ETL**  
  - Transform data **before** loading into the warehouse.  
  - Can reduce the load on the warehouse but requires an external compute engine (e.g., Glue, Qlik Compose).  

- **ELT**  
  - Load raw data **first** into the warehouse, then **transform** within the warehouse using SQL or similar.  
  - Leverages the **warehouse’s compute** (MPP) for large-scale transformations.

**In modern cloud architectures**, it’s increasingly common to see an **ELT** or **hybrid** approach, given the powerful compute capabilities of data warehouses like Redshift or Snowflake, and the flexibility to transform data after it’s landed.

---

## 4. Key Points for Each Phase

| **Phase**            | **Key Points**                                                                                   | **Tools/Services**                                                  |
|----------------------|------------------------------------------------------------------------------------------------|---------------------------------------------------------------------|
| **1. Ingestion**     | - Assess network bandwidth (Direct Connect, VPN).<br>- Identify frequency/real-time vs. batch.<br>- Secure data transfer (TLS, encryption). | AWS DMS, Qlik Replicate, AWS DataSync, AWS Transfer Family, Kinesis |
| **2. Data Lake (S3)**| - Store data at low cost.<br>- Keep raw data immutable for data lineage.<br>- Use separate S3 buckets or prefixes for raw/curated data. | Amazon S3 (with bucket policies, lifecycle rules)                   |
| **3. Transformation**| - Decide ETL vs. ELT approach.<br>- Cleanse, enrich, reformat (CSV → Parquet).<br>- Catalog metadata (Glue Data Catalog).              | AWS Glue, Qlik Compose, Talend, Informatica, EMR/Spark              |
| **4. Data Warehouse**| - OLAP-optimized schema (star/snowflake).<br>- Incremental or batch loading (COPY, Snowpipe).<br>- Partition and distribute data for performance. | Amazon Redshift, Snowflake on AWS                                   |
| **5. Analytics & ML**| - Provide dashboards, self-service analytics to end-users.<br>- Build ML models using curated data.<br>- Scale up big data use cases with EMR. | Qlik Sense, Tableau, Power BI, QuickSight, SageMaker, EMR           |

---

## 5. Why Use Qlik Suite (or Other Third-Party) Alongside AWS Glue

- **Qlik Replicate** (CDC): Seamlessly captures changes from source DB to keep data in sync, especially useful for **low-latency** replication to S3 or Redshift.  
- **Qlik Compose**: Automates data warehouse creation, transformations, and metadata management. It complements or replaces some of AWS Glue’s ETL features, particularly for organizations already standardized on Qlik for analytics.  
- **Mixed Environments**: Larger enterprises often have **diverse** tooling requirements, where combining AWS-native services (Glue, EMR) with third-party solutions (Qlik, Informatica, Talend) can address specialized needs or leverage existing licensing and expertise.

---

## Final Takeaways

1. **Phased Approach**: Breaking the pipeline into clear phases (Ingestion → Storage → Transformation → Warehouse → Analytics) ensures modularity, scalability, and manageability.  
2. **AWS Glue & Qlik**: You can combine AWS-native (AWS Glue) and third-party (Qlik Replicate/Compose) tools for robust data integration and transformation workflows.  
3. **Raw Data to Warehouse**: Data is landed in Amazon S3, **then** transformed (ETL/ELT) and **loaded** into an OLAP warehouse (Redshift/Snowflake) for business intelligence.  
4. **Scale & Flexibility**: The AWS ecosystem (S3, Glue, Redshift, Kinesis, EMR) is highly scalable; integrating Qlik or other top Gartner tools can enhance real-time data capture (CDC) and advanced data warehouse automation.  

With this approach, organizations can **quickly ingest** data from diverse sources, **transform** and **govern** it effectively, and **deliver** actionable insights through analytics and ML—all while leveraging a blend of AWS services and best-of-breed third-party solutions like Qlik.

---

## 1. High-Level Architecture Diagram (with AWS + Non-AWS Services)

``` 
                           +-------------------------------------+
                           |             Data Sources            |
                           |    (On-Prem DBs, APIs, SaaS, Files) |
                           +------------------+-------------------+
                                              |
                    +---------------------------------------------------+
                    |   Data Ingestion (Batch / Real-time)              |
                    |  e.g., Qlik Replicate, Informatica, Talend,       |
                    |  AWS DMS, Kinesis Data Firehose, etc.            |
                    +-------------------------+--------------------------+
                                              |
                                              v
               +---------------------------------------------------------------+
               |                Data Lake on Amazon S3 (Raw Data)             |
               | (Stores unstructured, semi-structured, or structured data)   |
               +---------------------------+-----------------------------------+
                                              |           
                                              |  [Optional Data Profiling]
                                              v
                            +--------------------------------------------------+
                            |  Data Integration / ETL / ELT Tools             |
                            |  (Qlik Compose, Informatica IICS, Talend, Glue) |
                            +--------------------------+-----------------------+
                                                           |
                                                           v
                              +------------------------------------------------+
                              |        Data Warehouse (AWS Redshift,           |
                              |   Snowflake, Oracle RDS, or other RDBMS)       |
                              +-------------------------+-----------------------+
                                                           |
                                                           v
                    +---------------------------------------------------------------+
                    |      BI & Visualization Tools (Front-End Analytics)          |
                    | Qlik Sense, QlikView, Tableau, Power BI, Amazon QuickSight   |
                    +----------------------------+----------------------------------+
                                                 |
                                                 v
                    +--------------------------------------------------------------+
                    |    Data Science / ML Platforms (Advanced Analytics)          |
                    |  AWS SageMaker, Databricks, Qlik AutoML*, etc.              |
                    +--------------------------------------------------------------+

```

> **Note**:  
> - *Qlik AutoML is a newer offering under Qlik’s analytics ecosystem.  
> - “IICS” stands for Informatica Intelligent Cloud Services.

---

## 2. Explanation of the Components

1. **Data Sources**  
   - These can include on-premise databases (Oracle, SQL Server), CRM systems (Salesforce), ERP systems (SAP), SaaS applications, IoT sensors, or flat files.

2. **Data Ingestion**  
   - **Qlik Replicate** (formerly Attunity Replicate): *Change Data Capture (CDC)* and batch ingestion from on-prem or cloud databases into your data lake or data warehouse.  
   - **Informatica** (IICS) or **Talend**: Popular enterprise-grade tools for data ingestion, data quality, and migration.  
   - **AWS DMS or Kinesis**: AWS-native services for migrating or streaming data into AWS.

3. **Data Lake on Amazon S3**  
   - Stores **raw data** as-is (structured, semi-structured, or unstructured).  
   - Often used for a “**Data Lake**” approach to retain all historical data at low cost.

4. **Data Integration / ETL / ELT Tools**  
   - **Qlik Compose**: Provides data transformation, data warehouse automation, and orchestration.  
   - **Informatica** or **Talend**: Offer robust ETL/ELT capabilities, data quality, and data governance features.  
   - **AWS Glue**: AWS-native ETL service that can discover data schemas and transform data.

5. **Data Warehouse**  
   - **AWS Redshift**: A scalable, columnar data warehouse on AWS, built for analytical (OLAP) workloads.  
   - **Snowflake**: A cloud-based, fully-managed data warehouse popular for multi-cloud deployments.  
   - **Oracle RDS / SQL Server RDS**: Managed relational databases on AWS—primarily for OLTP but can handle smaller-scale analytics in certain scenarios.

6. **BI & Visualization Tools**  
   - **Qlik Sense / QlikView**: A powerful, in-memory analytics suite for interactive dashboards and self-service BI.  
   - **Tableau**, **Power BI**, **Amazon QuickSight**: Other popular tools for data visualization, reporting, and ad-hoc analytics.

7. **Data Science / ML Platforms**  
   - **AWS SageMaker**: End-to-end machine learning service for building, training, and deploying models in AWS.  
   - **Databricks**: Unified analytics platform built on Spark for data engineering, machine learning, and collaborative analytics.  
   - **Qlik AutoML**: Allows analysts and data scientists to build ML models directly within the Qlik ecosystem.

---

## 3. Where Qlik & Other Gartner Leaders Fit In

- **Qlik**:  
  - *Qlik Replicate* for real-time or batch ingestion/CDC.  
  - *Qlik Compose* for automated data warehouse creation and data transformation.  
  - *Qlik Sense/QlikView* for dashboarding, self-service analytics, and data discovery.  
  - *Qlik AutoML* for automated machine learning on your datasets.

- **Informatica (IICS)** or **Talend**:  
  - Enterprise-grade data integration, data quality, governance, and ETL/ELT tools.  

- **AWS + Snowflake**:  
  - *AWS Redshift* or *Snowflake* typically serve as the analytical warehouse for structured data.  
  - *Amazon S3* as the raw data lake.

---

## 4. Key Architecture Highlights

1. **Flexible Ingestion**: Tools like **Qlik Replicate** or **Informatica** allow you to ingest data from various sources into the data lake or directly into the warehouse.  
2. **Data Lake Layer**: Storing raw data on **Amazon S3** keeps costs low and preserves data for advanced analytics or future use cases.  
3. **Transformation & Integration**: Solutions like **Qlik Compose**, **Talend**, or **Informatica** transform raw data into curated datasets.  
4. **Analytics & BI**: Tools such as **Qlik Sense**, **Tableau**, or **Power BI** connect to the **data warehouse** (or directly to the **data lake** via engines like Amazon Athena).  
5. **Advanced Analytics / ML**: Platforms such as **AWS SageMaker** or **Databricks** can leverage data in S3/Redshift/Snowflake for data science workloads.

---

## 5. Best Practices & Considerations

- **Separation of Concerns**: Keep ingestion, storage, transformation, and analytics layers modular to allow scaling or swapping tools without major rewrites.  
- **CDC for Real-time**: Use Qlik Replicate, Informatica CDC, or AWS DMS for capturing changes in near real-time from transactional systems.  
- **Security & Governance**: Implement role-based access, encryption (KMS for AWS S3, SSE for Redshift), and data governance (metadata catalogs, data lineage tools).  
- **Performance Optimization**:  
  - Data warehouse queries benefit from partitioning, distribution keys (Redshift), and columnar compression (Snowflake/Redshift).  
  - For Qlik-based solutions, ensure adequate RAM and consider in-memory aggregation for large datasets.

---

### Final Takeaways

- **Hybrid Approach**: Modern data architectures blend a **Data Lake** (S3) with a **Data Warehouse** (Redshift/Snowflake) for both scalable storage and fast analytics.  
- **Qlik Ecosystem**: Offers end-to-end data management (Replicate + Compose) and advanced analytics (Sense/View/AutoML).  
- **Other Gartner Leaders**: Informatica, Talend, Databricks, etc. can integrate seamlessly with AWS or multi-cloud environments to provide a robust data pipeline.  
- **Choose the Right Tool**: Your choice (Qlik, Informatica, Talend, etc.) often depends on data volume, real-time needs, existing skill sets, and licensing preferences.
---

## 1. **Differences Between a Database and a Data Warehouse**

| Aspect                | Database                                                 | Data Warehouse                                                                               |
|-----------------------|----------------------------------------------------------|----------------------------------------------------------------------------------------------|
| **Definition**        | A system designed to store and manage operational (transactional) data. | A centralized repository designed to store historical data from multiple sources for analytical and reporting purposes.             |
| **Use Case**          | Primarily used for day-to-day operations (OLTP – Online Transaction Processing). | Used for business intelligence, analytical queries, and decision-making (OLAP – Online Analytical Processing).                      |
| **Data Structure**    | Stores current data; typically normalized schema for efficient transactions. | Stores large volumes of historical data; schema often designed for aggregations (star or snowflake schema).                         |
| **Workload**          | Optimized for read-write (transactional) operations.     | Optimized for read (analytical) queries, aggregations, and complex joins.                     |
| **Performance**       | Focuses on quick read/write for individual transactions. | Focuses on batch loading, complex queries, and faster read of aggregated data.               |
| **Data Volume**       | Usually stores the current data needed for immediate operations. | Holds vast amounts of historical data for trending, forecasting, and analysis.               |
| **Typical Users**     | Application end users who process daily transactions.    | Analysts, data scientists, and business intelligence teams.                                  |

---

## 2. **Can AWS Oracle RDS Act as a Data Warehouse?**

- **AWS Oracle RDS** is a managed relational database service intended primarily for **transactional workloads (OLTP)**.  
- While it’s possible to run some analytical queries on RDS, it is **not recommended** for large-scale data warehousing because:
  - **Scalability**: Data warehouses often require horizontal scaling to handle massive data. RDS primarily scales vertically, which becomes limiting (and expensive).
  - **Performance**: Complex OLAP queries can degrade performance on a database that also handles frequent transactions.
  - **Cost & Maintenance**: Storing large historical datasets and running complex queries can become costly and less efficient compared to purpose-built systems.
- **Preferred Approach**: Use **AWS Redshift** or another dedicated data warehouse for large-scale analytics. You can replicate or ETL data from Oracle RDS into Redshift for best performance and scalability.

---

## 3. **Difference Between Data Warehouse and Data Lake**

| Aspect               | Data Warehouse                                                       | Data Lake                                                                                      |
|----------------------|----------------------------------------------------------------------|------------------------------------------------------------------------------------------------|
| **Data Structure**   | Structured or semi-structured data (transformed, cleansed).          | Stores data in any format (structured, semi-structured, unstructured) in raw form.             |
| **Schema**           | **Schema-on-write**: Data is cleansed and structured before loading. | **Schema-on-read**: Data is stored in raw form and only structured when it’s read/queried.     |
| **Storage**          | Typically uses relational or specialized analytical databases (columnar). | Usually uses low-cost object storage (e.g., Amazon S3, HDFS) for raw data.                      |
| **Primary Purpose**  | Business intelligence, dashboards, operational reporting.            | Exploratory analytics, data science, machine learning, and storing data "as-is" for future use. |
| **Data Quality**     | High level of data cleansing and quality checks before loading.      | Data can be raw and unprocessed; quality and relevance are typically managed at consumption.    |
| **Performance**      | Optimized for complex analytical queries, aggregations, and joins.   | Highly scalable storage; performance depends on the processing engine (e.g., Spark, Athena).    |
| **Cost**             | More expensive per GB due to specialized hardware/software.          | Lower-cost storage; pay for compute when processing data.                                       |
| **Use Cases**        | Historical trend analysis, BI dashboards, advanced analytics on clean data. | Data exploration, advanced analytics, ML workflows, storing data for unknown future needs.      |
| **Tools**            | AWS Redshift, Google BigQuery, Snowflake, traditional DW solutions.   | Amazon S3, Azure Data Lake Storage, Hadoop/HDFS, Delta Lake, and data processing engines.       |

---

## 4. **AWS Reference Architecture for Data & Analytics**

Below is a simplified **AWS Architecture Pattern** (in diagram format) showing how data typically flows from ingestion to analytics in a modern data estate. It combines both *data lake* and *data warehouse* principles.

``` 
                +-------------------------------------+
                |             Data Sources            |
                |  (On-Prem DBs, APIs, SaaS, Files)   |
                +------------------+-------------------+
                                   |
          +----------------------------------------------------+
          |    Data Ingestion (Batch / Real-time)              |
          |  e.g., AWS Glue Jobs, AWS DataSync, AWS DMS,       |
          |        Kinesis Firehose, AWS Transfer Family       |
          +-----------------------+-----------------------------+
                                  |
                                  v
             +-------------------------------------------------+
             |           Data Lake on Amazon S3                |
             |        (Raw, Unstructured, Semi-structured)     |
             +-----------------------+--------------------------+
                                  |           
                                  | [Optional Transform/Curate]
                                  v
                       +--------------------------------+
                       | AWS Glue Data Catalog & ETL     |
                       |  (Transform, Clean, Organize)   |
                       +-------------------+--------------+
                                           |
                                           v
                                +------------------------+
                                | AWS Redshift / RDS     |
                                |  (Data Warehouse)       |
                                +----------+--------------+
                                           |
                                           v
                             +------------------------------+
                             |   Analytics & Visualization   |
                             |  (Amazon QuickSight, Tableau, |
                             |   Power BI, etc.)            |
                             +------------------------------+
                                           |
                                           v
                             +------------------------------+
                             |    Data Science / ML Labs    |
                             | (Amazon SageMaker, EMR, etc.)|
                             +------------------------------+
```

### Explanation of Components

1. **Data Sources**  
   - Could be on-premise databases (Oracle, SQL Server), SaaS applications, flat files, or IoT devices.

2. **Data Ingestion**  
   - **AWS DataSync** or **AWS Transfer Family** for moving batch files to S3.  
   - **AWS DMS** (Database Migration Service) for replicating data from source DBs (like Oracle RDS) into S3 or Redshift.  
   - **Kinesis** (Streams/Firehose) for real-time data ingestion.

3. **Data Lake on Amazon S3**  
   - Stores raw data in its original format, be it CSV, JSON, parquet, images, logs, etc.

4. **AWS Glue Data Catalog & ETL**  
   - A fully managed ETL and data cataloging service. Helps discover data schema, transform/clean data, and prepare it for analytics.

5. **AWS Redshift or RDS (Data Warehouse)**  
   - **AWS Redshift**: A scalable, columnar storage data warehouse for analytical workloads (OLAP).  
   - **RDS**: Typically used for smaller OLTP or hybrid workloads, but not ideal for large-scale OLAP.

6. **Analytics & Visualization**  
   - **Amazon QuickSight**, **Tableau**, **Power BI**, or other tools that connect to Redshift (or directly to S3 via Athena) to create dashboards and reports.

7. **Data Science / ML**  
   - **Amazon SageMaker** for building, training, and deploying machine learning models.  
   - **Amazon EMR (Hadoop/Spark)** for large-scale data processing.

---

### Key Points to Remember

- **Data Lake + Data Warehouse (“Lakehouse”)**: Many modern architectures combine a **data lake** (for flexible, low-cost storage in raw form) with a **data warehouse** (for faster, structured analytics).  
- **AWS Oracle RDS** is **not** the best fit for a large-scale data warehouse solution.  
- **AWS Redshift** is purpose-built for OLAP workloads.  
- For end-to-end analytics, you can leverage **AWS Glue** for ETL, **Amazon S3** as the data lake, and **Amazon Redshift** as the data warehouse, with **Amazon QuickSight** or third-party tools for BI/visualization.

---

## Summary

- **Databases** handle day-to-day operational data (OLTP).  
- **Data Warehouses** handle historical and aggregated data for analytics (OLAP).  
- **AWS Oracle RDS** is mainly for transactional Oracle workloads, **not** ideal as a high-scale data warehouse.  
- **Data Lakes** (e.g., on S3) store raw data and are excellent for diverse data exploration, while **Data Warehouses** are optimized for structured analytics.  
- A **typical AWS data analytics architecture** involves ingestion (Glue, DMS, Kinesis), storage in a data lake (S3), optional transformation (Glue ETL), and loading to a data warehouse (Redshift) for BI and reporting, complemented by data science tools like SageMaker or EMR.
