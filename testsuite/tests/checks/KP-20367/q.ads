package Q is

   type Rec (D : Boolean := False) is record
      case D is
         when True  => I : Integer with Volatile;
         when False => null;
      end case;
   end record;

   type Rec_No_Default (D : Boolean) is record
      case D is
         when True  => I : Integer with Volatile;
         when False => null;
      end case;
   end record;

   type Rec_No_Discr is record
      I : Integer := 1;
   end record;

   procedure Fill (R : in out Rec);
   procedure Fill2 (R : in out Rec);
   procedure Read (R : in Rec) is null;
   procedure Init (R : out Rec) is null;

   procedure Fill (R : in out Rec_No_Default);
   procedure Fill (R : in out Rec_No_Discr);

end Q;
