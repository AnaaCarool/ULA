library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity ula2 is port
(
    A,B             :   in   signed(3 downto 0);
    Answer          :   out  std_logic_vector(3 downto 0);
    Operations      :   in   std_logic_vector(2 downto 0);
    Zero, Negative, Carry, Over  :   out  std_logic
);
end ula2;

architecture hardware of ula2 is
    signal Operations_temp : std_logic_vector(3 downto 0);
begin
    process(A, B, Operations)
        variable temp   : signed(4 downto 0); -- 5 bits para guardar carry
        variable a_int  : integer; -- transformando em inteiro para a divisão
        variable b_int  : integer;
		  variable o_int	: integer;
        variable Operations_int  : integer;
        variable temp_div : signed(3 downto 0); -- para divisão
        variable mult_result : signed(7 downto 0); -- para multiplicação
    begin
        -- Conversões de tipos
        a_int := to_integer(A);
        b_int := to_integer(B);
        
        -- Inicializar flags
        Carry <= '0';
        Over <= '0';
        
        case operations is
            when "000" =>  -- soma
                temp := resize(A, 5) + resize(B, 5);
                operations_temp <= std_logic_vector(temp(3 downto 0));
                Carry <= temp(4);
                -- Overflow para soma com sinal
                Over <= (A(3) and B(3) and not temp(3)) or 
                        (not A(3) and not B(3) and temp(3));
                        
            when "001" =>  -- subtração
                temp := resize(A, 5) - resize(B, 5);
                operations_temp <= std_logic_vector(temp(3 downto 0));
                Carry <= temp(4);
                -- Overflow para subtração com sinal
                Over <= (A(3) and not B(3) and not temp(3)) or 
                        (not A(3) and B(3) and temp(3));
                        
            when "010" =>  -- AND
                Operations_temp <= std_logic_vector(A) and std_logic_vector(B);
                
            when "011" =>  -- OR
                Operations_temp <= std_logic_vector(A) or std_logic_vector(B);
                
            when "100" =>  -- XOR
                Operations_temp <= std_logic_vector(A) xor std_logic_vector(B);
                
            when "101" =>  -- NOT A
                Operations_temp <= not std_logic_vector(A);
                
            when "110" =>  -- multiplicação
                mult_result := A * B;
                Operations_temp <= std_logic_vector(mult_result(3 downto 0));
                -- Carry se há bits significativos além dos 4 bits inferiores
                if mult_result(7 downto 4) /= "0000" and mult_result(7 downto 4) /= "1111" then
                    Carry <= '1';
                else
                    Carry <= '0';
                end if;
                -- Overflow se resultado não cabe em 4 bits com sinal
                if mult_result > 7 or mult_result < -8 then
                    Over <= '1';
                else
                    Over <= '0';
                end if;
                
            when others =>  -- divisão (operations = "111")
                if b_int /= 0 then
                    Operations_int := a_int / b_int;
                    temp_div := to_signed(o_int, 4);
                    Operations_temp <= std_logic_vector(temp_div);
                else
                    Operations_temp <= "0000"; -- divisão por zero = 0
                end if;
        end case;
        
    end process;
    
    -- Saídas
    Answer <= Operations_temp;
    Zero <= '1' when Operations_temp = "0000" else '0'; -- flag zero
    Negative <= Operations_temp(3); -- flag negativo (bit de sinal)
    
end hardware;