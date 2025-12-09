Library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity comparator is
  port (
	  inp_A,inp_B   : in std_logic_vector(31 downto 0);
	  equal : out std_logic
   );
end comparator ; 

architecture bhv of comparator is
begin
equal <= '1' when (inp_A = inp_B)
else '0';
end bhv;