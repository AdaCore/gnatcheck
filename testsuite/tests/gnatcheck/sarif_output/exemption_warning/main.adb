procedure Main is
begin
   --## rule off goto_statements
   --## rule on goto_statements
   goto x;  -- FLAG
   <<x>>
end Main;
