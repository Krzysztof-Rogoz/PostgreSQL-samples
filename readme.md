PostgreSQL Database Samples

A collection of sample databases for PostgreSQL.

1) "The Magic of digits"
2) Virtual months generator - TBD
3) Row level security - TBD


Ad 1) "The Magic of digits" is a complete solution,
  including environments setup and automatic unit tests.
  Example of temporary function perform complex calculations on
  the list of integers (in decimal format). Analysis included digits
  and returns the length of the longest sequence of items (integers) 
  consisting of 2 digits only   


Ad 2) "Virtual months generator" is example of function returning
  calendar months in format YYYY-MM as records

Ad 3) "Row level security" is example of implementation
  iof application-level RLS. Set up sample user entitlements
  table, data/facts table and Postgres view returning only records
  that current user is eligible to see. Current user from application
  is setup as session variable.
