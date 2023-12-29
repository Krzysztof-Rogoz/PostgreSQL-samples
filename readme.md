<b>PostgreSQL Database Samples</b>

A collection of sample databases for PostgreSQL.

1) DB Backup & Restore
2) InMemory JSON dictionary
3) "The Magic of digits"
4) Virtual months generator
5)   Row level security - TBD
6)   Refresh grants - TBD
7)   Change objects ownership - TBD
8)   Monitoring / Explain plan in pgAdmin  - TBD


Ad 1) "DB Backup & Restore"
  Integrated enterprise solution to maintain Postgres data
  Synchronizes data across environments (e.g.Prod->Dev)
  Configurable and customizable, can be used as template / design pattern
 #DBA #DevOps #DataMigration #Datareplication
 #GitLab #pipeline #jobs #yaml #Hashicorp #security #auth
 #Azure #Linux #bash #db_dump #psql

Ad 2) "InMemory JSON dictionary"
  Function to provide additional data (e.g. alias or description) in select or view
  using input column as index, without joining additional tables, no performance impact
  Sample contains use case.

Ad 3) "The Magic of digits" is a complete solution,
  including environments setup and automatic unit tests.
  Example of temporary function perform complex calculations on
  the list of integers (in decimal format). Analysis included digits
  and returns the length of the longest sequence of items (integers) 
  consisting of 2 digits only   


Ad 4) "Virtual months generator" is example of function returning
  calendar months in format YYYY-MM as records

Ad 5) "Row level security" is example of implementation
  iof application-level RLS. Set up sample user entitlements
  table, data/facts table and Postgres view returning only records
  that current user is eligible to see. Current user from application
  is setup as session variable.