CREATE OR REPLACE PACKAGE etl AS
   PROCEDURE load_from_tab;
   PROCEDURE load_from_view;
   PROCEDURE load_from_syn;
   PROCEDURE load_from_syn_wild;
   PROCEDURE load_from_syn_log;
   PROCEDURE load_multi_table;
   PROCEDURE load_from_implicit_cursor;
   PROCEDURE load_from_explicit_cursor;
END etl;
/
