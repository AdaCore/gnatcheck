procedure Main is
   subtype Small is Integer range 1 .. 10;

   subtype One is Small with Static_Predicate => One = 1;
   subtype Two is Small with Predicate => Two = 2;

   S : constant Small := 5;
   B : Boolean;
begin
   case S is
      when One    =>  -- FLAG
         null;

      when Two    =>  -- FLAG
         null;

      when 5      =>  -- NOFLAG
         null;

      when others =>  -- NOFLAG
         null;
   end case;

   B :=
     (case S is
        when One    => False,  -- FLAG
        when Two    => True,   -- FLAG
        when 5      => True,   -- NOFLAG
        when others => True);  -- NOFLAG
end Main;
