<b>PostgreSQL Database Samples</b>

A collection of sample databases for PostgreSQL.

1) "The Magic of digits"
2) Virtual months generator
3) InMemory JSON dictionary
4) Row level security - TBD


Ad 1) "The Magic of digits" is a complete solution,
  including environments setup and automatic unit tests.
  Example of temporary function perform complex calculations on
  the list of integers (in decimal format). Analysis included digits
  and returns the length of the longest sequence of items (integers) 
  consisting of 2 digits only   


Ad 2) "Virtual months generator" is example of function returning
  calendar months in format YYYY-MM as records

Ad 3) "InMemory JSON dictionary"
  Function to provide additional data (e.g. aliase or description) in select or view
  using input column as index, without joining additional tables, no performance impact
  Sample contains use case.

Ad 4) "Row level security" is example of implementation
  iof application-level RLS. Set up sample user entitlements
  table, data/facts table and Postgres view returning only records
  that current user is eligible to see. Current user from application
  is setup as session variable.
