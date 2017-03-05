CREATE OR REPLACE PACKAGE etl AS
   PROCEDURE load_from_tab;
   PROCEDURE load_from_view;
   PROCEDURE load_from_syn;
   PROCEDURE load_from_syn_wild;
END etl;
/
