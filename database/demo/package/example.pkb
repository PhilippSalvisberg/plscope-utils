create or replace package body example as
   procedure forward_declared_procedure;

   procedure top_level_procedure is
      procedure second_level_procedure is
         procedure third_level_procedure is
            function fourth_level_function(in_value in integer) return integer is
               procedure fifth_level_procedure is
               begin
                  sys.dbms_output.put_line('fifth_level_procedure');
                  commit;
               end fifth_level_procedure;
            begin
               fifth_level_procedure;
               return in_value;
            end fourth_level_function;
         begin
            sys.dbms_output.put_line('third_level_procedure:' || fourth_level_function(42));
            commit;
         end third_level_procedure;
      begin
         third_level_procedure;
      end second_level_procedure;
   begin
      second_level_procedure;
   end top_level_procedure;

   procedure forward_declared_procedure is
   begin
      sys.dbms_output.put_line('forward_declared_procedure');
      commit;
   end forward_declared_procedure;
end example;
/
