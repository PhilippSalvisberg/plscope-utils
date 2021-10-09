-- 1. enable PL/Scope in session
alter session set plscope_settings = 'identifiers:all, statements:all';

create or replace procedure load_from_tab is
begin
   insert into deptsal (dept_no, dept_name, salary)
   select /*+ordered */
          d.deptno, d.dname, sum(e.sal + nvl(e.comm, 0)) as sal
     from dept d
     left join (
             select *
               from emp
              where hiredate > date '1980-01-01'
          ) e
       on e.deptno = d.deptno
    group by d.deptno, d.dname;
   commit;
end load_from_tab;
/

-- 2. query original PL/Scope identifiers 
select line,
       col,
       name,
       type,
       usage,
       signature, -- SELECT * FROM all_identifiers WHERE type = 'TABLE' AND usage = 'DECLARATION'
       usage_id,
       usage_context_id
  from user_identifiers
 where object_name = 'LOAD_FROM_TAB'
 order by line, col;
 
-- 3. query original PL/Scope statements
select line, col, sql_id, type, full_text, has_hint, signature, usage_id, usage_context_id
  from user_statements
 where object_name = 'LOAD_FROM_TAB'
 order by line, col;
 
-- 4. combine identifiers and statements, report hierarchy level, references
with
   ids as (
      select name,
             signature,
             type,
             object_name,
             object_type,
             usage,
             usage_id,
             line,
             col,
             usage_context_id,
             origin_con_id
        from user_identifiers
      union all
      select nvl(sql_id, type) as name,
             signature,
             type,
             object_name,
             object_type,
             'EXECUTE' as usage, -- new, artificial usage
             usage_id,
             line,
             col,
             usage_context_id,
             origin_con_id
        from user_statements
   )
select ids.line,
       ids.col,
       ids.name,
       sys_connect_by_path(replace(ids.name, '/'), '/') as name_path,
       ids.type,
       ids.usage,
       refs.object_type as ref_object_type,
       refs.object_name as ref_object_name
  from ids
  left join user_identifiers refs
    on refs.signature = ids.signature
   and refs.usage = 'DECLARATION'
 where ids.object_name = 'LOAD_FROM_TAB'
 start with ids.usage_context_id = 0
connect by prior ids.usage_id = ids.usage_context_id
   and prior ids.object_type = ids.object_type
   and prior ids.object_name = ids.object_name
 order by ids.line, ids.col;

-- 5. query plscope-utils identifiers
select line,
       col,
       name,
       name_path,
       type,
       usage,
       ref_owner,
       ref_object_type,
       ref_object_name
  from plscope_identifiers
 where object_name = 'LOAD_FROM_TAB'
 order by line, col;

-- 6. query all columns in plscope-utils identifiers
select *
  from plscope_identifiers
 where object_name = 'LOAD_FROM_TAB'
 order by line, col;
 
-- 7. query plscope-utils statements (adds a is_duplicate column)
select *
  from plscope_statements
 where object_name = 'LOAD_FROM_TAB'
 order by owner, object_type, object_name, line, col;
   
-- 8. query duplicate statements
select *
  from plscope_statements
 where is_duplicate = 'YES';
