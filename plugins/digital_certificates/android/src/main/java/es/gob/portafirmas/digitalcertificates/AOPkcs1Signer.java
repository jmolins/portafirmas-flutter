/* Copyright (C) 2011 [Gobierno de Espana]
 * This file is part of "Cliente @Firma".
 * "Cliente @Firma" is free software; you can redistribute it and/or modify it under the terms of:
 *   - the GNU General Public License as published by the Free Software Foundation;
 *     either version 2 of the License, or (at your option) any later version.
 *   - or The European Software License; either version 1.1 or (at your option) any later version.
 * Date: 11/01/11
 * You may contact the copyright holder at: soporte.afirma5@mpt.es
 */

package es.gob.portafirmas.digitalcertificates;

import java.security.NoSuchAlgorithmException;
import java.security.NoSuchProviderException;
import java.security.PrivateKey;
import java.security.Signature;
import java.security.SignatureException;
import java.security.cert.Certificate;
import java.util.Properties;

/** Firmador simple en formato PKCS#1.
 * @author Tom&aacute;s Garc&iacute;a-Mer&aacute;s */
public final class AOPkcs1Signer {

	/** Realiza una firma electr&oacute;nica PKCS#1 v1.5.
	 * @param algorithm Algoritmo de firma a utilizar
	 * <p>Se aceptan los siguientes algoritmos en el par&aacute;metro <code>signatureAlgorithm</code>:</p>
	 * <ul>
	 *  <li><i>SHA1withRSA</i></li>
	 *  <li><i>SHA256withRSA</i></li>
	 *  <li><i>SHA384withRSA</i></li>
	 *  <li><i>SHA512withRSA</i></li>
	 * </ul>
	 * @param key Clave privada a usar para la firma.
	 * @param certChain Se ignora, esta clase no necesita la cadena de certificados.
	 * @param data Datos a firmar.
	 * @param extraParams Se ignora, esta clase no acepta par&aacute;metros adicionales.
	 * @return Firma PKCS#1 en binario puro no tratado.
	 * @throws {@link AOException} en caso de cualquier problema durante la firma. */
	public byte[] sign(final byte[] data, final String algorithm, final PrivateKey key, final Certificate[] certChain, final Properties extraParams) throws AOException {
		final Signature sig;

		try {
			// En Android las capacidades de los proveedores, aunque se declaren bien, no se manejan adecuadamente
			if ("com.aet.android.providerPKCS15.SEPrivateKey".equals(key.getClass().getName())) {
				sig = Signature.getInstance(algorithm, "AETProvider");
			}
			else if ("es.gob.jmulticard.jse.provider.DniePrivateKey".equals(key.getClass().getName())) {
				java.util.logging.Logger.getLogger("es.gob.afirma").info("Detectada clave privada DNIe 100% Java");
				sig = Signature.getInstance(algorithm, "DNIeJCAProvider");
			}
			else if ("es.gob.jmulticard.jse.provider.ceres.CeresPrivateKey".equals(key.getClass().getName())) {
				java.util.logging.Logger.getLogger("es.gob.afirma").info("Detectada clave privada CERES 100% Java");
				sig = Signature.getInstance(algorithm, "CeresJCAProvider");
			}
			else {
				sig = Signature.getInstance(algorithm);
			}
		}
		catch (final NoSuchAlgorithmException e) {
			throw new AOException("No se soporta el algoritmo de firma (" + algorithm + "): " + e, e);
		}
		catch (final NoSuchProviderException e) {
			throw new AOException("No hay un proveedor para el algoritmo '" + algorithm + "' con el tipo de clave '" + key.getAlgorithm() + "': " + e, e);
		}

		try {
			sig.initSign(key);
		}
		catch (final Exception e) {
			throw new AOException("Error al inicializar la firma con la clave privada: " + e, e);
		}

		try {
			sig.update(data);
		}
		catch (final SignatureException e) {
			throw new AOException("Error al configurar los datos a firmar: " + e, e);
		}

		try {
			return sig.sign();
		}
		catch (final SignatureException e) {
			throw new AOException("Error durante el proceso de firma PKCS#1: " + e, e);
		}
	}
}
