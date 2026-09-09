procedure Main is
   type Invalid is new Integer;  -- FLAG
begin
   goto lbl;  --  FLAG

   if True then null;

   <<lbl>>;
end Name;
