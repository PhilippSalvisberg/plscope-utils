create table dept (
   deptno   number(2)     constraint pk_dept primary key,
   dname    varchar2(14),
   loc      varchar2(13)
);

insert into dept values (10, 'ACCOUNTING', 'NEW YORK');
insert into dept values (20, 'RESEARCH', 'DALLAS');
insert into dept values (30, 'SALES', 'CHICAGO');
insert into dept values (40, 'OPERATIONS', 'BOSTON');
commit;
