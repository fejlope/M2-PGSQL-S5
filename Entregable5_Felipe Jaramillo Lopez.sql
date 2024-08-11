Se debe subir un archivo .sql con el script que contenga todos los procedimientos y se debe entregar por medio de Pull Request.

1. Crear una nueva cuenta bancaria1. 

CREATE PROCEDURE crear_cuenta(
	IN cliente_id INTEGER, 
	IN numero_cuenta VARCHAR, 
	IN tipo_cuenta VARCHAR, 
	IN saldo INTEGER, 
	IN fecha_apertura DATE, 
	IN estado VARCHAR)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO public.cuentas (cliente_id, numero_cuenta, tipo_cuenta, saldo, fecha_apertura, estado) 
    VALUES (cliente_id, numero_cuenta, tipo_cuenta, saldo, fecha_apertura, estado) ;
END;
$$;

CALL crear_cuenta (10, 'BNCOL2021-3','nomina', 5000, CURRENT_DATE, 'activa' );

2. Actualizar la información del cliente

CREATE PROCEDURE update_cliente(
	IN id_cli INTEGER, 
	IN dir_cli VARCHAR, 
	IN tel_cli VARCHAR, 
	IN mail_cli VARCHAR )
LANGUAGE plpgsql
AS $$
BEGIN
	UPDATE public.clientes SET direccion = dir_cli, telefono = tel_cli, correo_electronico = mail_cli WHERE cliente_id = id_cli ;
END;
$$;

CALL update_cliente (20, 'Plaza Mayor','012-345-3040', 'elena.munoz@example.com.co');

3. Eliminar una cuenta bancaria

-- consultar el nombre de la CONSTRAINT
SELECT constraint_name 
FROM information_schema.table_constraints 
WHERE table_name = 'transacciones' AND constraint_type = 'FOREIGN KEY';

-- eliminar CONSTRAINT existente
ALTER TABLE public.transacciones DROP CONSTRAINT transacciones_cuenta_id_fkey;

-- crear de nuevo el CONSTRAINT
ALTER TABLE public.transacciones ADD CONSTRAINT transacciones_cuenta_id_fkey 
FOREIGN KEY (cuenta_id) REFERENCES Cuentas(cuenta_id) ON DELETE CASCADE;

CREATE PROCEDURE eliminar_cuenta(
	IN id_cuenta INTEGER)
LANGUAGE plpgsql
AS $$
BEGIN
	DELETE FROM public.cuentas WHERE cuenta_id = id_cuenta;
END;
$$;

CALL eliminar_cuenta (3);

4. Transferir fondos entre cuentas

CREATE PROCEDURE transferencia(
	IN vlr_transferncia INTEGER,
	IN cuenta_origen VARCHAR,
	IN cuenta_destino VARCHAR)
LANGUAGE plpgsql
AS $$
DECLARE
	id_cuenta_origen INTEGER;

BEGIN
	UPDATE public.cuentas SET saldo = (saldo - vlr_transferncia) WHERE  numero_cuenta = cuenta_origen ;
	UPDATE public.cuentas SET saldo = (saldo + vlr_transferncia) WHERE  numero_cuenta = cuenta_destino ;
	INSERT INTO public.transacciones (cuenta_id, 	tipo_transaccion, 	monto, fecha_transaccion, descripcion) VALUES 
		((select cuenta_id from public.cuentas  WHERE  numero_cuenta = cuenta_origen), 'transferencia', vlr_transferncia,	CURRENT_DATE, 'Transferencia a la cuenta: ' || cuenta_destino);	
	INSERT INTO public.transacciones (cuenta_id, 	tipo_transaccion, 	monto, fecha_transaccion, descripcion) VALUES 
		((select cuenta_id from public.cuentas  WHERE  numero_cuenta = cuenta_destino), 'transferencia', vlr_transferncia, CURRENT_DATE, 'Transferencia de la cuenta: ' || cuenta_origen);
END;
$$;

CALL transferencia (2000, '2345678901', '1234567890');


5. Agregar una nueva transacción

CREATE PROCEDURE nueva_transaccion(
	IN vlr_transaccion INTEGER,
	IN cuenta VARCHAR,
	IN tipo_transaccion VARCHAR)

LANGUAGE plpgsql
AS $$
DECLARE
	saldo_nuevo INTEGER;
BEGIN
	INSERT INTO public.transacciones (cuenta_id, tipo_transaccion, monto, fecha_transaccion, descripcion) VALUES 
		((select cuenta_id from public.cuentas  WHERE  numero_cuenta = cuenta), tipo_transaccion, vlr_transaccion, CURRENT_DATE,  tipo_transaccion || ' cuenta :' || cuenta);     	

	saldo_nuevo := CASE 
			WHEN tipo_transaccion = 'deposito' THEN ((SELECT saldo from public.cuentas where numero_cuenta = cuenta) + vlr_transaccion)
			WHEN tipo_transaccion = 'Retiro' THEN ((SELECT saldo from public.cuentas where numero_cuenta = cuenta) - vlr_transaccion)
			ELSE (SELECT saldo from public.cuentas where numero_cuenta = cuenta)
	END;

	UPDATE public.cuentas SET saldo = (saldo_nuevo) WHERE  numero_cuenta = cuenta ;

END;
$$;

CALL nueva_transaccion (5000, '2345678901', 'Retiro');


6. Calcular el saldo total de todas las cuentas de un cliente

CREATE PROCEDURE saldo_cuentas(
	IN cuentaid INTEGER)

LANGUAGE plpgsql
AS $$
DECLARE
	saldo_total INTEGER;
BEGIN
	saldo_total = (
	select sum(saldo) as saldo_total from public.cuentas
		where  cuentas.cliente_id = cuentaid) ; 
	
	RAISE NOTICE 'EL saldo total combinado de todas las cuentas es: %', saldo_total;
END;
$$;

CALL saldo_cuentas (11);

7. Generar un reporte de transacciones para un rango de fechas

	
CREATE OR REPLACE PROCEDURE reporte_transacciones(
	IN fecha_inicio TIMESTAMP,
	IN fecha_final TIMESTAMP)

LANGUAGE plpgsql
AS $$
DECLARE
    transaccion RECORD;
BEGIN
	FOR transaccion IN
        SELECT 	numero_cuenta, 	tipo_transaccion, 	monto, 	fecha_transaccion, 	descripcion
        FROM public.transacciones
        JOIN public.cuentas ON transacciones.cuenta_id = cuentas.cuenta_id
        WHERE transacciones.fecha_transaccion::DATE BETWEEN fecha_inicio AND fecha_final
	   ----WHERE transacciones.fecha_transaccion::DATE BETWEEN '2022-01-01' AND '2023-12-31'   
        ORDER BY transacciones.fecha_transaccion
    LOOP
        RAISE NOTICE 'Cuenta: %, Tipo: %, Monto: %, Fecha: %, Descripcion: %',
                      transaccion.numero_cuenta, transaccion.tipo_transaccion, transaccion.monto, transaccion.fecha_transaccion, transaccion.descripcion;
    END LOOP;
END;
$$;

CALL reporte_transacciones('2022-01-01', '2023-12-31');
