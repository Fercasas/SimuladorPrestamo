SET NOCOUNT ON

/*Parametros iniciales*/
DECLARE 
--Importe o valor del prestamo
@Importe    MONEY = 10000000
DECLARE 
--Plazo en meses
@PLazo    INT = 12
DECLARE 
--Tasa Efectiva Anual (porcentaje)
@TasaAnual    FLOAT = 15.36
DECLARE 
--Valor mensual por productos externos como seguros
@Externos    MONEY = 0

BEGIN
	DECLARE 
	@Mensaje         VARCHAR(250), 
	@MensajeError    VARCHAR(250), 
	@Int             FLOAT, 
	@CuotaBase       MONEY, 
	@Principal       MONEY, 
	@Intereses       MONEY, 
	@PpalPte         MONEY

	BEGIN TRY
		SET @Mensaje = '>>> Validaciones'
		PRINT @Mensaje
		IF @Importe <= 0
		BEGIN
			SET @MensajeError = 'El importe no puede ser menor o igual que cero'
			RAISERROR(@MensajeError, 16, 1)
		END
		IF @TasaAnual < 0
		BEGIN
			SET @MensajeError = 'La tasa efectiva anual no puede ser menor que cero'
			RAISERROR(@MensajeError, 16, 1)
		END
		IF @Plazo < 1
		BEGIN
			SET @MensajeError = 'El plazo no puede ser menor a 1 mes'
			RAISERROR(@MensajeError, 16, 1)
		END
		SET @Mensaje = concat(CHAR(9), '> Importe: ', @Importe)
		PRINT @Mensaje
		SET @Mensaje = concat(CHAR(9), '> TEA: ', @TasaAnual)
		PRINT @Mensaje
		SET @Mensaje = concat(CHAR(9), '> Plazo: ', @Plazo, ' Meses')
		PRINT @Mensaje
		SET @Mensaje = concat(CHAR(9), '> Producto externos: ', @Externos)
		PRINT @Mensaje

		SET @Mensaje = '>>> Calculos iniciales'
		PRINT @Mensaje
		IF @TasaAnual > 0
		BEGIN
			SELECT @Int = @TasaAnual / 100 / 12
			SELECT @CuotaBase = CEILING((@Int + @Int / (POWER(1 + @Int, @Plazo) - 1)) * @Importe)
			SELECT @CuotaBase = IIF(@CuotaBase > @Importe + @Int * @Importe, @Importe + @Int * @Importe, @CuotaBase)
		END
			ELSE
		BEGIN
			SELECT @Int = 0
			SELECT @CuotaBase = CEILING(@Importe / @Plazo)
		END
		SET @Mensaje = concat(CHAR(9), '> Cuota mensual: ', @CuotaBase + @Externos)
		PRINT @Mensaje

		SELECT @Principal = CAST(ROUND(@CuotaBase - @Importe * @Int, 0) AS MONEY)
		SELECT @Intereses = CAST(ROUND(@Importe * @Int, 0) AS MONEY)
		SELECT @PpalPte = CAST(ROUND(@Importe - @Principal, 0) AS MONEY)

		SET @Mensaje = '>>> Generar tabla de amortizaci�n'
		PRINT @Mensaje

		;WITH Amortizacion
			 AS (SELECT 1 AS                      Periodo
					  , @CuotaBase AS             CuotaBase
					  , @CuotaBase + @Externos AS Cuota
					  , @Principal AS             Principal
					  , @Intereses AS             Intereses
					  , @Externos AS              Externos
					  , @PpalPte AS               PpalPte
				 UNION ALL
				 SELECT Periodo + 1 AS                                               Periodo
					  , CASE
							WHEN PpalPte + ROUND(PpalPte * @Int, 0) < CuotaBase
								THEN CAST(PpalPte + ROUND(PpalPte * @Int, 0) AS MONEY)
							ELSE CuotaBase
						END AS                                                       CuotaBase
					  , CASE
							WHEN PpalPte + ROUND(PpalPte * @Int, 0) < CuotaBase
								THEN CAST(PpalPte + ROUND(PpalPte * @Int, 0) AS MONEY)
							ELSE CuotaBase
						END + Externos AS                                            Cuota
					  , CAST(CASE
								 WHEN PpalPte + ROUND(PpalPte * @Int, 0) < CuotaBase
									 THEN CAST(PpalPte + ROUND(PpalPte * @Int, 0) AS MONEY)
								 ELSE CuotaBase
							 END - ROUND(PpalPte * @Int, 0) AS MONEY) AS             Principal
					  , CAST(ROUND(PpalPte * @Int, 0) AS MONEY) AS                   Intereses
					  , Externos
					  , CAST(ROUND(PpalPte - (CASE
												  WHEN PpalPte + ROUND(PpalPte * @Int, 0) < CuotaBase
													  THEN CAST(PpalPte + ROUND(PpalPte * @Int, 0) AS MONEY)
												  ELSE CuotaBase
											  END - PpalPte * @Int), 0) AS MONEY) AS PpalPte
				 FROM Amortizacion
				 WHERE Periodo < @Plazo)

			 SELECT concat('Mes', ' ', Periodo) AS Periodo
				  , CuotaBase
				  , Cuota
				  , Principal
				  , Intereses
				  , Externos
				  , PpalPte
			 FROM Amortizacion AS a
	END TRY
	BEGIN CATCH
		SET @MensajeError = CONCAT('ERROR', ' [', COALESCE(@Mensaje, ''), ']: ', COALESCE(ERROR_MESSAGE(), ''))
		RAISERROR(@MensajeError, 16, 1)
	END CATCH
END