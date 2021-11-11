CREATE FUNCTION dbo.UDF_Pago
(
	@Tasa    NUMERIC(18, 10), 
	@Nper    INT, 
	@Va      NUMERIC(18, 10), 
	@Vf      NUMERIC(18, 10), 
	@Tipo    BIT
)
RETURNS NUMERIC(18, 4)
AS
/*
	Función que calcula el pago de un préstamo basándose en pagos y tasa de interés constantes.

	Parameters	:
	@Tasa		: Tasa de interés del prestamo por periodo
	@Nper		: Número total de pagos del prestámo
	@Va			: Valor actual   
	@Vf			: Es el valor futuro o saldo en efectivo que se desea lograr después de efectuar el último pago
	@Tipo		: Número 0 o 1 que indica cuándo vencen los pagos. 0 = al final del periodo, 1 = al inicio del periodo

	Ejecución:
	SELECT dbo.UDF_Pago (0.0129, 12, -10000000, 0, 0)

	Autor: Fernando Casas Osorio
*/
BEGIN
	DECLARE 
	@Pago    NUMERIC(18, 4)  

	SELECT @Tasa = COALESCE(@Tasa, 0)
	SELECT @Nper = COALESCE(@Nper, 0)
	SELECT @Va = COALESCE(@Va, 0)
	SELECT @Vf = COALESCE(@Vf, 0)
	SELECT @Tipo = COALESCE(@Tipo, 0)

	--VALIDACIONES
	IF @Tasa < 0 OR @Nper < 1
	BEGIN
		GOTO FIN
	END

	IF @Tasa > 0
	BEGIN
		SELECT @Pago = @Tasa / (POWER(1.0 + @Tasa, @Nper) - 1.0) * -(@Va * POWER(1.0 + @Tasa, @Nper) + @Vf)
	END
		ELSE
	BEGIN
		SELECT @Pago = -((@Va + @Vf) / @Nper)
	END

	IF @Tipo = 1
	BEGIN
		SELECT @Pago = @Pago / (1 + @Tasa)
	END

	FIN:
	RETURN @Pago
END