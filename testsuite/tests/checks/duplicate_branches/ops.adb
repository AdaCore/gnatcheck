procedure Ops
  (A, B, C, D, E, F, G, H : Integer;
   Flag                   : Boolean;
   X                      : out Integer) is
begin
   if Flag then
      X := A + B + C + D + E + F + G + H;   --  FLAG with line 9
   else
      X := A + B + C + D + E + F + G + H;
   end if;
end Ops;
