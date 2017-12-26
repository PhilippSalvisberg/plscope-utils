CREATE OR REPLACE PACKAGE BODY test_plscope_context IS
   
   --
   -- test_set_attr
   --
   PROCEDURE test_set_attr IS
      l_actual   VARCHAR2(4000 BYTE);
   BEGIN
      plscope_context.set_attr('my_name','1');
      l_actual := sys_context('PLSCOPE', 'my_name');
      ut.expect(l_actual).to_equal('1');
   END test_set_attr;
   
   --
   -- test_remove_attr
   --
   PROCEDURE test_remove_attr IS
      l_actual   VARCHAR2(4000 BYTE);
   BEGIN
      plscope_context.set_attr('my_name','1');
      plscope_context.remove_attr('my_name');
      l_actual := sys_context('PLSCOPE', 'my_name');
      ut.expect(l_actual).to_(be_null);
   END test_remove_attr;

   --
   -- test_remove_all
   --
   PROCEDURE test_remove_all IS
      l_actual INTEGER;
   BEGIN
      plscope_context.set_attr('my_name1','1');
      plscope_context.set_attr('my_name2','2');
      plscope_context.set_attr('my_name3','3');
      plscope_context.set_attr('my_name4','4');
      plscope_context.remove_all;
      SELECT COUNT(*) 
        INTO l_actual
        FROM session_context
       WHERE namespace = 'PLSCOPE';
      ut.expect(l_actual).to_equal(0);
   END test_remove_all;

END test_plscope_context;
/
