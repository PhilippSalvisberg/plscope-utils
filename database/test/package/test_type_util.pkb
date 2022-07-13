create or replace package body test_type_util is

   --
   -- test_dedup_t_obj
   --
   procedure test_dedup_t_obj is
      t_input    t_obj_type;
      t_actual   t_obj_type;
      t_expected t_obj_type;
   begin
      t_input    := t_obj_type(
                       obj_type('MY_OWNER', 'VIEW', 'MY_VIEW'),
                       obj_type('MY_OWNER', 'PACKAGE', 'MY_PACKAGE'),
                       obj_type('MY_OWNER', 'VIEW', 'MY_VIEW')
                    );
      t_expected := t_obj_type(
                       obj_type('MY_OWNER', 'PACKAGE', 'MY_PACKAGE'),
                       obj_type('MY_OWNER', 'VIEW', 'MY_VIEW')
                    );
      t_actual   := type_util.dedup(t_input);
      ut.expect(t_actual.count).to_equal(2);
      ut.expect(sys.anydata.convertcollection(t_actual)).to_equal(sys.anydata.convertcollection(t_expected)).unordered;
   end test_dedup_t_obj;
   
   --
   -- test_dedup_t_col
   --
   procedure test_dedup_t_col is
      t_input    t_col_type;
      t_actual   t_col_type;
      t_expected t_col_type;
   begin
      t_input    := t_col_type(
                       col_type('MY_OWNER', 'VIEW', 'MY_VIEW', 'COL1'),
                       col_type('MY_OWNER', 'VIEW', 'MY_VIEW', 'COL2'),
                       col_type('MY_OWNER', 'VIEW', 'MY_VIEW', 'COL3'),
                       col_type('MY_OWNER', 'VIEW', 'MY_VIEW', 'COL2'), -- duplicate
                       col_type('MY_OWNER', 'VIEW', 'MY_VIEW', 'COL1') -- duplicate
                    );
      t_expected := t_col_type(
                       col_type('MY_OWNER', 'VIEW', 'MY_VIEW', 'COL1'),
                       col_type('MY_OWNER', 'VIEW', 'MY_VIEW', 'COL2'),
                       col_type('MY_OWNER', 'VIEW', 'MY_VIEW', 'COL3')
                    );
      t_actual   := type_util.dedup(t_input);
      ut.expect(t_actual.count).to_equal(3);
      ut.expect(sys.anydata.convertcollection(t_actual)).to_equal(sys.anydata.convertcollection(t_expected)).unordered;
   end test_dedup_t_col;

   --
   -- test_dedup_t_col_lineage
   --
   procedure test_dedup_t_col_lineage is
      t_input    t_col_lineage_type;
      t_actual   t_col_lineage_type;
      t_expected t_col_lineage_type;
   begin
      t_input    := t_col_lineage_type(
                       col_lineage_type('U1', 'T1', 'O1', 'C1', 'U1', 'T1', 'O2', 'C1'),
                       col_lineage_type('U1', 'T1', 'O1', 'C2', 'U1', 'T1', 'O2', 'C2'),
                       col_lineage_type('U1', 'T1', 'O1', 'C1', 'U1', 'T1', 'O2', 'C1') -- duplicate
                    );
      t_expected := t_col_lineage_type(
                       col_lineage_type('U1', 'T1', 'O1', 'C1', 'U1', 'T1', 'O2', 'C1'),
                       col_lineage_type('U1', 'T1', 'O1', 'C2', 'U1', 'T1', 'O2', 'C2') -- duplicate
                    );
      t_actual   := type_util.dedup(t_input);
      ut.expect(t_actual.count).to_equal(2);
      ut.expect(sys.anydata.convertcollection(t_actual)).to_equal(sys.anydata.convertcollection(t_expected)).unordered;
   end test_dedup_t_col_lineage;

end test_type_util;
/
