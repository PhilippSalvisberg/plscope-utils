create or replace package body test_plscope_context is
   
   --
   -- test_set_attr
   --
   procedure test_set_attr is
      l_actual varchar2(4000 byte);
   begin
      plscope_context.set_attr('my_name', '1');
      l_actual := sys_context('PLSCOPE', 'my_name');
      ut.expect(l_actual).to_equal('1');
   end test_set_attr;
   
   --
   -- test_remove_attr
   --
   procedure test_remove_attr is
      l_actual varchar2(4000 byte);
   begin
      plscope_context.set_attr('my_name', '1');
      plscope_context.remove_attr('my_name');
      l_actual := sys_context('PLSCOPE', 'my_name');
      ut.expect(l_actual).to_(be_null);
   end test_remove_attr;

   --
   -- test_remove_all
   --
   procedure test_remove_all is
      l_actual integer;
   begin
      plscope_context.set_attr('my_name1', '1');
      plscope_context.set_attr('my_name2', '2');
      plscope_context.set_attr('my_name3', '3');
      plscope_context.set_attr('my_name4', '4');
      plscope_context.remove_all;
      select count(*)
        into l_actual
        from session_context
       where namespace = 'PLSCOPE';
      ut.expect(l_actual).to_equal(0);
   end test_remove_all;

end test_plscope_context;
/
