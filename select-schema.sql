set quoted_identifier on
(select '/*COL*/'
  + 'alter table [' + s.name + '].[' + t.name + '] add [' + c.name + '] ' + ty.name
  + case
  when ty.name in ('char', 'varchar')
  then '(' + case when c.max_length < 0 then 'max' else ltrim(str(c.max_length)) end + ') --collate ' + c.collation_name
  when ty.name in ('numeric')
  then '(' + cast(c.precision as varchar) + ', ' + cast(c.scale as varchar) + ')'
  when ty.name in ('nvarchar')
  then '(' + case when c.max_length < 0 then 'max' else ltrim(str(c.max_length / 2)) end + ') --collate ' + c.collation_name
  else ''
  end
  + case when c.is_identity <> 0 then 'identity(1, 1)' else '' end + ' ' + case when c.is_nullable <> 0 then 'null' else 'not null' end + ';'
  + ' --' + ltrim(str(c.precision)) + ',' + ltrim(str(c.scale))
  ss
  from sys.tables t
  join sys.schemas s on t.schema_id = s.schema_id and s.name <> 'sys'
  join sys.columns c on t.object_id = c.object_id
  join sys.types ty on c.system_type_id = ty.system_type_id and ty.name != 'sysname'
union select '/*DC*/alter table [' + s.name + '].[' + t.name + '] add constraint ' + dc.name + ';'
  from sys.objects t
  join sys.default_constraints dc on t.object_id = dc.parent_object_id
  join sys.schemas s on t.schema_id = s.schema_id and s.name <> 'sys'
union select '/*FG'
  + '|' + o.type + '|' + coalesce(s.name, '') + '|' + coalesce(o.name, '') + '|' + coalesce(i.name, '') + '|' + coalesce(f.name, '')
  + '*/'
  collate SQL_Latin1_General_CP1_CI_AS ss
  from sys.all_objects o
  join sys.schemas s on o.schema_id = s.schema_id and s.name <> 'sys'
  join sys.indexes i on i.object_id = o.object_id
  join sys.filegroups f on i.data_space_id = f.data_space_id
  and i.name is null
union select distinct '/*FK' 
  + case when fk.is_disabled = 1 then ' DISABLED' else '' end
  + case when fk.is_not_trusted = 1 then ' UNTRUSTED' else '' end
  + '*/'
  --+ 'alter table [' + p_s.name + '].[' + p_t.name + '] with check add constraint ' + p_t.name + '_' + c_t.name + '_FK foreign key ('
  + 'alter table [' + p_s.name + '].[' + p_t.name + '] with check add constraint [' + fk.name + '] foreign key ('
  + substring(stuff((
    select ', [' + p_c.name + ']'
    from sys.foreign_key_columns fkc
    join sys.columns p_c on p_c.object_id = fkc.parent_object_id and p_c.column_id = fkc.parent_column_id
    where fkc.constraint_object_id = fk.object_id
    order by fkc.constraint_column_id
    for xml path(''), type).value('.', 'nvarchar(max)')
    ,1,0,''), 3, 99999)
  + ') references [' + c_s.name + '].[' + c_t.name + '] ('
  + substring(stuff((
    select ', [' + c_c.name + ']'
    from sys.foreign_key_columns fkc
    join sys.columns c_c on c_c.object_id = fkc.referenced_object_id and c_c.column_id = fkc.referenced_column_id
    where fkc.constraint_object_id = fk.object_id
    order by fkc.constraint_column_id
    for xml path(''), type).value('.', 'nvarchar(max)')
    ,1,0,''), 3, 99999)
  + ');' ss
  from sys.objects o
  join sys.foreign_keys fk on o.object_id = fk.parent_object_id
  join sys.foreign_key_columns fkc on fk.object_id = fkc.constraint_object_id
  join sys.objects p_t on p_t.object_id = fkc.parent_object_id
  join sys.schemas p_s on p_t.schema_id = p_s.schema_id and p_s.name <> 'sys'
  join sys.objects c_t on c_t.object_id = fkc.referenced_object_id
  join sys.schemas c_s on c_t.schema_id = c_s.schema_id
union select '/*IX*/create index [' + i.name + '] on [' + s.name + '].[' + t.name + '] ('
  + substring(stuff((
    select ', ' + co.name
    from sys.index_columns ic
    join sys.columns co on co.object_id = i.object_id and co.column_id = ic.column_id
    where ic.object_id = i.object_id
    and ic.index_id = i.index_id
    and ic.is_included_column = 0
    order by key_ordinal
    for xml path(''), type).value('.', 'nvarchar(max)')
    ,1,0,''), 3, 99999)
  + isnull(') include ('
    + substring(stuff((
      select ', ' + co.name
      from sys.index_columns ic
      join sys.columns co on co.object_id = i.object_id and co.column_id = ic.column_id
      where ic.object_id = i.object_id
      and ic.index_id = i.index_id
      and ic.is_included_column = 1
      order by key_ordinal
      for xml path(''), type).value('.', 'nvarchar(max)')
      ,1,0,''), 3, 99999)
    , ''
  )
  + ') on [' + coalesce(f.name, '') + ']'
  + ';' ss
  from sys.objects t
  join sys.indexes i on t.object_id = i.object_id
  join sys.schemas s on t.schema_id = s.schema_id and s.name <> 'sys'
  join sys.filegroups f on i.data_space_id = f.data_space_id
  where i.type = 2
  --and i.is_unique = 0
  and i.is_primary_key = 0
  and t.[type] = 'U'
  --and ic.is_included_column = 0
union select '/*PK*/alter table [' + s.name + '].[' + t.name + '] add constraint ' + i.name + ' primary key clustered ('
  + substring(stuff((
    select ', [' + c.name + ']' + case when ic.is_descending_key = 1 then ' desc' else '' end
    from sys.index_columns ic
    join sys.columns c on ic.object_id = c.object_id and ic.column_id = c.column_id
    where i.index_id = ic.index_id and i.object_id = ic.object_id
    order by key_ordinal
    for xml path(''), type).value('.', 'nvarchar(max)')
    ,1,0,''), 3, 99999)
  + ') on [' + coalesce(f.name, '') + ']'
  + ';' ss
  from sys.objects t
  join sys.indexes i on t.object_id = i.object_id
  join sys.schemas s on t.schema_id = s.schema_id and s.name <> 'sys'
  join sys.filegroups f on i.data_space_id = f.data_space_id
  where i.is_primary_key = 1
union select '/*UK*/alter table [' + s.name + '].[' + t.name + '] add constraint ' + i.name + ' unique ('
  + substring(stuff((
    select ', ' + c.name
    from sys.index_columns ic
    join sys.columns c on ic.object_id = c.object_id and ic.column_id = c.column_id
    where i.index_id = ic.index_id and i.object_id = ic.object_id
    order by key_ordinal
    for xml path(''), type).value('.', 'nvarchar(max)')
    ,1,0,''), 3, 99999)
  + ');' ss
  from sys.indexes i
  join sys.objects t on i.object_id = t.object_id
  join sys.schemas s on t.schema_id = s.schema_id and s.name <> 'sys'
  where i.is_unique_constraint = 1
)
order by ss
