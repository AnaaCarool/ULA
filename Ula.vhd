-- =============================================================================
-- ENTIDADE DEBOUNCE
-- =============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity debounce is
generic (
    CLOCK_FREQ_MHZ : integer := 50;
    DEBOUNCE_TIME_MS : integer := 20;  --contador q confirma a mudança de estado se o botao permanecer
    --estável por um tempo configurável
    RESET_ACTIVE_LOW : boolean := false;
    INPUT_ACTIVE_LOW : boolean := false
);
port (
    clk : in std_logic; --clock do fpga
    reset : in std_logic;  --reset configurável
    button_in : in std_logic;  --botao cru (KEY0)
    --cada vez q apertar KEY0 vai gerar um pulso limpo de 1 ciclo
    button_out : out std_logic; --nivel estavel do botao
    rising_pulse : out std_logic;  --pulso de 1 ciclo de clock quando botao passa de 0 p/ 1
    falling_pulse : out std_logic --o contrario
);
end entity debounce;

architecture rtl of debounce is
    --retorna true quando reset está ativo conforme o RESET_ACTIVE_LOW
    function is_reset_active(signal rst : std_logic) return boolean is 
    begin
        if RESET_ACTIVE_LOW then
            return rst = '0';
        else
            return rst = '1';
        end if;
    end function;
--aplica a polaridade configurável do botão
    function normalize_input(signal inp : std_logic) return std_logic is
    begin
        if INPUT_ACTIVE_LOW then
            return not inp;
        else
            return inp;
        end if;
    end function;

    --quantos ciclos o sinal precisa ficar inalterado para ser considerável estável
    constant COUNTER_MAX : integer := (CLOCK_FREQ_MHZ * 1000) * DEBOUNCE_TIME_MS - 1;
    subtype counter_type is integer range 0 to COUNTER_MAX;

    signal counter : counter_type := 0;  --conta estabilidade
    signal sync_ff : std_logic_vector(2 downto 0) := (others => '0'); --resgistrador p/ sincronizar...
    --a entrada de clock e reduzir metastabilidade
    signal button_clean : std_logic := '0'; --ultimo nível estável confirmado
    signal button_prev : std_logic := '0'; --valor estável do ciclo anterior(para gerar pulsos)
    signal reset_n : std_logic; --(ativo em 0)
    signal button_norm : std_logic; --versao normalizada
begin
    --normalizaçoes
    reset_n <= '0' when is_reset_active(reset) else '1';
    button_norm <= normalize_input(button_in);

--sincronizaçao
    sync_process: process(clk, reset_n)
    begin
        if reset_n = '0' then
            sync_ff <= (others => '0');
        elsif rising_edge(clk) then
            sync_ff <= sync_ff(1 downto 0) & button_norm; --desloca sync_ff e insere button no LSB
        end if;
    end process sync_process;

    debounce_process: process(clk, reset_n)
    begin
        if reset_n = '0' then
            counter <= 0;
            button_clean <= '0';
            button_prev <= '0';
        elsif rising_edge(clk) then
            button_prev <= button_clean; --para gerar pulsos depois

            if sync_ff(2) /= sync_ff(1) then --se detectar mudança
                counter <= 0; --recomeça estabilidade
            else
                if counter < COUNTER_MAX then
                    counter <= counter + 1;
                else
                    button_clean <= sync_ff(2); --"confirma" a mudança
                end if;
            end if;
        end if;
    end process debounce_process;

    button_out <= button_clean; --preserva o nível estável
    rising_pulse <= button_clean and not button_prev;
    falling_pulse <= not button_clean and button_prev;
--cada clique em KEYX vera um único pulso de 1 ciclo (limpo)
end architecture rtl;

-- =============================================================================
-- ENTIDADE ULA2
-- =============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity ula2 is
port (
    A, B : in signed(3 downto 0);
    Answer : out std_logic_vector(3 downto 0); --resultado
    Operations : in std_logic_vector(2 downto 0);
    Zero, Negative, Carry, Over : out std_logic
);
end ula2;

architecture hardware of ula2 is
    signal Operations_temp : std_logic_vector(3 downto 0); --registrador interno
begin
    process(A, B, Operations)
        variable temp : signed(4 downto 0); 
        variable mult_result : signed(7 downto 0); --(para ver estouro)
    begin
        -- Inicializar flags
        Carry <= '0';
        Over <= '0';

        case operations is
            when "000" => -- soma
                temp := resize(A, 5) + resize(B, 5);
                operations_temp <= std_logic_vector(temp(3 downto 0));
                Carry <= temp(4);
                Over <= (A(3) and B(3) and not temp(3)) or
                       (not A(3) and not B(3) and temp(3));

            when "001" => -- subtração
                temp := resize(A, 5) - resize(B, 5);
                operations_temp <= std_logic_vector(temp(3 downto 0));
                Carry <= temp(4);
                Over <= (A(3) and not B(3) and not temp(3)) or
                       (not A(3) and B(3) and temp(3));

            when "010" => -- AND
                Operations_temp <= std_logic_vector(A) and std_logic_vector(B);

            when "011" => -- OR
                Operations_temp <= std_logic_vector(A) or std_logic_vector(B);

            when "100" => -- XOR
                Operations_temp <= std_logic_vector(A) xor std_logic_vector(B);

            when "101" => -- NOT A
                Operations_temp <= not std_logic_vector(A);

            when "110" => -- multiplicação
                mult_result := A * B;
                Operations_temp <= std_logic_vector(mult_result(3 downto 0));
                if mult_result(7 downto 4) /= "0000" and mult_result(7 downto 4) /= "1111" then
                    Carry <= '1';
                -- OU to_signed(7, 8)
                else
                    Carry <= '0';
                end if;
                if mult_result > 7 or mult_result < -8 then
                    Over <= '1';
                else
                    Over <= '0';
                end if;

            when "111" => -- shift left lógico de A
                temp := resize(A, 5) + resize(A, 5);
                operations_temp <= std_logic_vector(temp(3 downto 0));
                Carry <= temp(4);
                Over <= (A(3)and not A(2)) or
                       (not A(3) and A(2));

            when others =>
                Operations_temp <= "0000";
        end case;
    end process;

    Answer <= Operations_temp;
    Zero <= '1' when Operations_temp = "0000" else '0';
    Negative <= Operations_temp(3);
end hardware;

-- =============================================================================
-- ENTIDADE TOP_LEVEL 
-- =============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity top_level is
port(
    -- CLOCK E RESET
    CLOCK_50 : in std_logic;
    RESET_N : in std_logic;

    -- BOTÕES DE CONTROLE
    KEY0 : in std_logic; -- Botão para confirmar entrada
    KEY1 : in std_logic; -- Botão para alternar modo (operação/operandos)

    -- SWITCHES DE ENTRADA 
    SW : in std_logic_vector(3 downto 0);

    -- LEDS DE SAÍDA
    LEDG : out std_logic_vector(3 downto 0); -- Resultado
    LEDR : out std_logic_vector(7 downto 0)  -- FLAGS + Estado
);
end top_level;

architecture rtl of top_level is
    -- Declaração de componentes
    component debounce is
    generic (
        CLOCK_FREQ_MHZ : integer := 50;
        DEBOUNCE_TIME_MS : integer := 20;
        RESET_ACTIVE_LOW : boolean := false;
        INPUT_ACTIVE_LOW : boolean := false
    );
    port (
        clk : in std_logic;
        reset : in std_logic;
        button_in : in std_logic;
        button_out : out std_logic;
        rising_pulse : out std_logic;
        falling_pulse : out std_logic
    );
    end component;

    component ula2 is
    port (
        A, B : in signed(3 downto 0);
        Answer : out std_logic_vector(3 downto 0);
        Operations : in std_logic_vector(2 downto 0);
        Zero, Negative, Carry, Over : out std_logic
    );
    end component;

    -- Sinais internos
    signal reset_internal : std_logic;
    signal btn0_pulse, btn1_pulse : std_logic;

    -- Estados da máquina de entrada
    type input_state_type is (INPUT_OP, INPUT_A, INPUT_B, SHOW_RESULT);
    signal input_state : input_state_type := INPUT_OP;

    -- Registradores internos para armazenar valores
    signal operacao_reg : std_logic_vector(2 downto 0) := "000";
    signal operando_a_reg : std_logic_vector(3 downto 0) := "0000";
    signal operando_b_reg : std_logic_vector(3 downto 0) := "0000";
    signal resultado : std_logic_vector(3 downto 0);

    -- Flags da ULA
    signal flag_zero, flag_negative, flag_carry, flag_overflow : std_logic;

begin
    reset_internal <= not RESET_N;

    -- Instâncias do debounce para os botões
    debounce_key0: debounce
    generic map (
        CLOCK_FREQ_MHZ => 50,
        DEBOUNCE_TIME_MS => 20,
        RESET_ACTIVE_LOW => false,
        INPUT_ACTIVE_LOW => true
    )
    port map (
        clk => CLOCK_50,
        reset => reset_internal,
        button_in => KEY0,
        button_out => open,
        rising_pulse => btn0_pulse,
        falling_pulse => open
    );

    debounce_key1: debounce
    generic map (
        CLOCK_FREQ_MHZ => 50,
        DEBOUNCE_TIME_MS => 20,
        RESET_ACTIVE_LOW => false,
        INPUT_ACTIVE_LOW => true
    )
    port map (
        clk => CLOCK_50,
        reset => reset_internal,
        button_in => KEY1,
        button_out => open,
        rising_pulse => btn1_pulse,
        falling_pulse => open
    );

    -- Máquina de estados para entrada sequencial
    input_fsm: process(CLOCK_50, reset_internal)
    begin
        if reset_internal = '1' then
            input_state <= INPUT_OP;
            operacao_reg <= "000";
            operando_a_reg <= "0000";
            operando_b_reg <= "0000";
        elsif rising_edge(CLOCK_50) then
            case input_state is
                when INPUT_OP =>
                    if btn0_pulse = '1' then
                        operacao_reg <= SW(2 downto 0); -- Só usa 3 bits para operação
                        input_state <= INPUT_A;
                    end if;

                when INPUT_A =>
                    if btn0_pulse = '1' then
                        operando_a_reg <= SW;
                        input_state <= INPUT_B;
                    elsif btn1_pulse = '1' then
                        input_state <= INPUT_OP; -- Volta para operação
                    end if;

                when INPUT_B =>
                    if btn0_pulse = '1' then
                        operando_b_reg <= SW;
                        input_state <= SHOW_RESULT;
                    elsif btn1_pulse = '1' then
                        input_state <= INPUT_A; -- Volta para operando A
                    end if;

                when SHOW_RESULT =>
                    if btn1_pulse = '1' then
                        input_state <= INPUT_OP; -- Reinicia processo
                    end if;
            end case;
        end if;
    end process;

    -- Instância da ULA
    ula_inst: ula2
    port map (
        A => signed(operando_a_reg),
        B => signed(operando_b_reg),
        Operations => operacao_reg,
        Answer => resultado,
        Zero => flag_zero,
        Negative => flag_negative,
        Carry => flag_carry,
        Over => flag_overflow
    );


    -- Saídas
    LEDG <= resultado;

    -- LEDs vermelhos: estados + flags
    LEDR(7 downto 6) <= std_logic_vector(to_unsigned(input_state_type'pos(input_state), 2));
    LEDR(5 downto 4) <= "00"; -- Reservado
    LEDR(3) <= flag_overflow;
    LEDR(2) <= flag_carry;
    LEDR(1) <= flag_negative;
    LEDR(0) <= flag_zero;

end architecture rtl;