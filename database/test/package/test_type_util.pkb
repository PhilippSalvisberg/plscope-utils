CREATE OR REPLACE PACKAGE BODY test_type_util IS

   --
   -- test_dedup_t_obj
   --
   PROCEDURE test_dedup_t_obj IS
      l_input    t_obj_type;
      l_actual   t_obj_type;
      l_expected t_obj_type;
   BEGIN
      l_input := t_obj_type(
                    obj_type('MY_OWNER', 'VIEW', 'MY_VIEW'),
                    obj_type('MY_OWNER', 'PACKAGE', 'MY_PACKAGE'),
                    obj_type('MY_OWNER', 'VIEW', 'MY_VIEW')
                 );
      l_expected := t_obj_type(
                       obj_type('MY_OWNER', 'PACKAGE', 'MY_PACKAGE'),
                       obj_type('MY_OWNER', 'VIEW', 'MY_VIEW')
                    );
      l_actual := type_util.dedup(l_input);
      ut.expect(l_actual.count).to_equal(2);
      ut.expect(anydata.convertCollection(l_actual))
         .to_equal(anydata.convertCollection(l_expected)).unordered; 
   END test_dedup_t_obj;
   
   --
   -- test_dedup_t_col
   --
   PROCEDURE test_dedup_t_col IS
      l_input    t_col_type;
      l_actual   t_col_type;
      l_expected t_col_type;
   BEGIN
      l_input := t_col_type(
                    col_type('MY_OWNER', 'VIEW', 'MY_VIEW', 'COL1'),
                    col_type('MY_OWNER', 'VIEW', 'MY_VIEW', 'COL2'),
                    col_type('MY_OWNER', 'VIEW', 'MY_VIEW', 'COL3'),
                    col_type('MY_OWNER', 'VIEW', 'MY_VIEW', 'COL2'), -- duplicate
                    col_type('MY_OWNER', 'VIEW', 'MY_VIEW', 'COL1') -- duplicate
                 );
      l_expected := t_col_type(
                       col_type('MY_OWNER', 'VIEW', 'MY_VIEW', 'COL1'),
                       col_type('MY_OWNER', 'VIEW', 'MY_VIEW', 'COL2'),
                       col_type('MY_OWNER', 'VIEW', 'MY_VIEW', 'COL3')
                    );
      l_actual := type_util.dedup(l_input);
      ut.expect(l_actual.count).to_equal(3);
      ut.expect(anydata.convertCollection(l_actual))
         .to_equal(anydata.convertCollection(l_expected)).unordered;
   END test_dedup_t_col;

   --
   -- test_dedup_t_col_lineage
   --
   PROCEDURE test_dedup_t_col_lineage IS
      l_input    t_col_lineage_type;
      l_actual   t_col_lineage_type;
      l_expected t_col_lineage_type;
   BEGIN
      l_input := t_col_lineage_type(
                    col_lineage_type('U1','T1','O1','C1','U1','T1','O2','C1'),
                    col_lineage_type('U1','T1','O1','C2','U1','T1','O2','C2'),
                    col_lineage_type('U1','T1','O1','C1','U1','T1','O2','C1') -- duplicate
                 );
      l_expected := t_col_lineage_type(
                       col_lineage_type('U1','T1','O1','C1','U1','T1','O2','C1'),
                       col_lineage_type('U1','T1','O1','C2','U1','T1','O2','C2') -- duplicate
                 );
      l_actual := type_util.dedup(l_input);
      ut.expect(l_actual.count).to_equal(2);
      ut.expect(anydata.convertCollection(l_actual))
         .to_equal(anydata.convertCollection(l_expected)).unordered;
   END test_dedup_t_col_lineage;

END test_type_util;
/
