procedure Main is
   procedure P1 (X : in Integer; Y : out Boolean);  --  FLAG
   procedure P2 (X : out Integer; Y : in Boolean);  --  NOFLAG
begin
   null;
end Main;
