library ieee;
use ieee.std_logic_1164.all;

entity debounce is
  generic(
    clk_freq    : integer := 40_000_000;  --Determinando frequencia de clock em Hz
    stable_time : integer := 25);         --Estabilizando o tempo (em ms)
  port(
    clk     : in  std_logic;  --clock input
    reset_n : in  std_logic;  --reset
    button  : in  std_logic;  --valor de entrada do flip-flop
    result  : out std_logic); --sinal após o debouncing
END debounce;

architecture logic of debounce is
  signal flipflops   : std_logic_vector(1 downto 0); --valor dos flip-flops (ff1,ff2)
  signal counter_set : std_logic;                    --contador para zerar os ffs
begin

  counter_set <= flipflops(0) xor flipflops(1);  --determinação de quando dar o reset (ff1 xor ff2)
  
  process(clk, reset_n) -- processando o clock e o reset
    variable count :  integer range 0 to clk_freq*stable_time/1000;  --contador
  begin
    if(reset_n = '0') then                           -- verificando se reset esta ligado
      flipflops(1 downto 0) <= "00";                 --resetando o valor dos ffs (00)
      result <= '0';                                 --resetando o valor do resultado
    elsif(clk'event and clk = '1') then              --verificando se o butão foi pressionado
      flipflops(0) <= button;                        --guardando o valor no primeiro ff
      flipflops(1) <= flipflops(0);                  --guardando o valor do ff1 no segundo ff
      if(counter_set = '1') then                     --resetando o contador (mudança do input)
        count := 0;
      elsif(count < clk_freq*stable_time/1000) then  --verificando se o tempo de estabildade foi alcançado
        count := count + 1;                          --somando um à variavel count, caso estabilidade não tenha sido alcançada
      else                                           --verificando se o tempo de estabildade foi alcançado
        result <= flipflops(1);                      --a saída é o falor do ultimo ff2, caso esteja estável
      end if;    
    end if;
  end process;
  
end logic;