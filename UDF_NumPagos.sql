CREATE FUNCTION dbo.UDF_NumPagos
(
	@Tasa    NUMERIC(18, 10), 
	@Pago    INT, 
	@Va      NUMERIC(18, 10), 
	@Vf      NUMERIC(18, 10), 
	@Tipo    BIT
)
RETURNS NUMERIC(18, 4)
AS
/*
	Función que calcula el número de pagos de un préstamo basándose en pagos y tasa de interés constantes.

	Parameters	:
	@Tasa		: Tasa de interés del prestamo por periodo
	@Pago		: Pago efectuado cada periodo
	@Va			: Valor actual   
	@Vf			: Es el valor futuro o saldo en efectivo que se desea lograr después de efectuar el último pago
	@Tipo		: Número 0 o 1 que indica cuúndo se realizan los pagos. 0 = al final del periodo, 1 = al inicio del periodo

	Ejecución:
	SELECT dbo.UDF_NumPagos (0.0129, 100000, -1105155, 0, 0)

	Autor: Fernando Casas Osorio
*/
BEGIN
	DECLARE 
	@NumPagos    NUMERIC(18, 4), 
	@K           DECIMAL(10, 8)

	SELECT @Tasa = COALESCE(@Tasa, 0)
	SELECT @Va = COALESCE(@Va, 0)
	SELECT @Vf = COALESCE(@Vf, 0)
	SELECT @Tipo = COALESCE(@Tipo, 0)

	--VALIDACIONES
	IF @Tasa < 0 OR @Pago <= 0
	BEGIN
		GOTO FIN
	END

	IF @Tipo = 0
	BEGIN
		SET @K = 1
	END
		ELSE
	BEGIN
		SET @K = 1 + @Tasa
	END

	SELECT @NumPagos = CEILING(LOG((-@Vf * (@Tasa / @K) + @Pago) / (@Pago + (@Tasa / @K) * @Va)) / LOG(1 + @Tasa))

	FIN:
	RETURN @NumPagos
END