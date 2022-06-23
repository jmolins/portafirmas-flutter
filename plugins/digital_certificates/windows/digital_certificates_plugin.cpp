// Copyright 2022. Chema Molins.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
#include "include/digital_certificates/digital_certificates_plugin.h"

#include <windows.h>

#include <VersionHelpers.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar.h>
#include <flutter/standard_method_codec.h>
#include <memory>
#include <sstream>

#include <iostream>
#include <iterator>
#include <codecvt>
#include <algorithm>

#include <bcrypt.h>
#include <ncrypt.h>
#include <wincrypt.h>
#include <cryptuiapi.h>

#pragma comment (lib, "crypt32.lib")
#pragma comment (lib, "cryptui.lib")
#pragma comment (lib, "bcrypt.lib")
#pragma comment (lib, "ncrypt.lib")

#define MY_ENCODING_TYPE  (PKCS_7_ASN_ENCODING | X509_ASN_ENCODING)

#define NT_SUCCESS(Status)          (((NTSTATUS)(Status)) >= 0)
#define STATUS_UNSUCCESSFUL         ((NTSTATUS)0xC0000001L)

namespace {

  class DigitalCertificatesPlugin : public flutter::Plugin {

  public:
    static void RegisterWithRegistrar(flutter::PluginRegistrar* registrar);

    // Creates a plugin that communicates on the given channel.
    DigitalCertificatesPlugin(
      std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel);

    virtual ~DigitalCertificatesPlugin();

  private:

    HCERTSTORE       hCertStore = NULL;
    PCCERT_CONTEXT   pCertContext = NULL;

    void CleanUp();
    void CleanBCryptHashObjects(BCRYPT_ALG_HANDLE hAlg, BCRYPT_HASH_HANDLE hHash, PBYTE pbHashObject, PBYTE pbHash);

    // Called when a method is called on |channel_|;
    void HandleMethodCall(
      const flutter::MethodCall<>& method_call,
      std::unique_ptr<flutter::MethodResult<>> result);

    // The MethodChannel used for communication with the Flutter engine.
    std::unique_ptr<flutter::MethodChannel<>> channel_;
  };

  // static
  void DigitalCertificatesPlugin::RegisterWithRegistrar(flutter::PluginRegistrar* registrar) {
    auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        registrar->messenger(), "digital_certificates",
        &flutter::StandardMethodCodec::GetInstance());
    auto* channel_pointer = channel.get();

    auto plugin = std::make_unique<DigitalCertificatesPlugin>(std::move(channel));

    channel_pointer->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
      plugin_pointer->HandleMethodCall(call, std::move(result));
    });

    registrar->AddPlugin(std::move(plugin));
  };

  DigitalCertificatesPlugin::DigitalCertificatesPlugin(
    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel)
    : channel_(std::move(channel)) {}

  DigitalCertificatesPlugin::~DigitalCertificatesPlugin() {
    CleanUp();
  };

  void DigitalCertificatesPlugin::HandleMethodCall(
    const flutter::MethodCall<>& method_call,
    std::unique_ptr<flutter::MethodResult<>> result) {

    if (method_call.method_name().compare("selectCertificate") == 0) {

      // HELP
      // https://github.com/garmonbozzzia/XmlSignWebService/blob/master/csp-integral-test/tools/certificate-search.cpp
      // https://github.com/rbmm/LIB/blob/master/ASIO/ssl.cpp

      // Clean up previous variables in case they are still around
      CleanUp();

      // Aternativa para abrir el almacén de sistema:
      // if (!(hCertStore = CertOpenSystemStore(NULL, L"MY"))) {
      hCertStore = CertOpenStore(CERT_STORE_PROV_SYSTEM, X509_ASN_ENCODING,
        0, CERT_STORE_OPEN_EXISTING_FLAG | CERT_SYSTEM_STORE_CURRENT_USER, L"MY");
      if (!hCertStore) {
        result->Error("certificate_error", "No se ha podido abrir el almacén de certificados.");
        return;
      }
      pCertContext = CryptUIDlgSelectCertificateFromStore(hCertStore, NULL, NULL, NULL,
        CRYPTUI_SELECT_LOCATION_COLUMN, 0, NULL);
      if (!pCertContext) {
        result->Error("certificate_error", "Error al seleccionar el certificado");
        return;
      }

      // Muestra en una ventana la información del certificado seleccionado.
      // CryptUIDlgViewContext(CERT_STORE_CERTIFICATE_CONTEXT, pCertContext, NULL, NULL, 0, NULL);

      DWORD size;
      if (CryptBinaryToString(pCertContext->pbCertEncoded, pCertContext->cbCertEncoded,
        CRYPT_STRING_BASE64HEADER, NULL, &size)) {
        // Initialize the Long Pointer to Wide string properly
        std::vector< wchar_t > wide_buffer(size);
        LPWSTR certificate = &wide_buffer[0];
        if (CryptBinaryToString(pCertContext->pbCertEncoded, pCertContext->cbCertEncoded, CRYPT_STRING_BASE64, certificate, &size)) {
          // Print wide string to standard output
          //std::wcout << certificate << std::endl;

          std::wostringstream certificate_stream;
          certificate_stream << certificate << std::endl;

          // wide to UTF-8
          std::wstring_convert<std::codecvt_utf8<wchar_t>> conv1;
          std::string u8str = conv1.to_bytes(certificate_stream.str());
          //std::cout << u8str << std::endl;

          result->Success(flutter::EncodableValue(u8str));
          return;
        }
      }
      // Remember to close the CertStore
      // CertCloseStore(hCertStore, 0);
      result->Error("certificate_error", "Error obteniendo el certificado.");

    }
    else if (method_call.method_name().compare("certificateSubject") == 0) {

      LPTSTR pszName;
      DWORD cbSize;

      cbSize = CertGetNameString(
        pCertContext,
        CERT_NAME_SIMPLE_DISPLAY_TYPE,
        0,
        NULL,
        NULL,
        0);
      if (!cbSize)
      {
        std::cout << "CertGetNameString 1 failed" << std::endl;
        result->Error("certificate_error", "CertGetNameString 1 failed.");
      }

      pszName = (LPTSTR)malloc(cbSize * sizeof(TCHAR));
      if (!pszName)
      {
        std::cout << "Memory allocation failed" << std::endl;
        result->Error("certificate_error", "Memory allocation failed in CertGetNameString.");
      }

      if (!CertGetNameString(
        pCertContext,
        CERT_NAME_SIMPLE_DISPLAY_TYPE,
        0,
        NULL,
        pszName,
        cbSize))
      {
        std::cout << "CertGetNameString failed." << std::endl;
        result->Error("certificate_error", "CertGetNameString failed.");
      }

      std::wostringstream subject_stream;
      subject_stream << pszName << std::endl;

      std::wstring_convert<std::codecvt_utf8<wchar_t>> conv1;
      std::string u8str = conv1.to_bytes(subject_stream.str());

      result->Success(flutter::EncodableValue(u8str));

    }
    else if (method_call.method_name().compare("signData") == 0) {

      //https://github.com/open-eid/chrome-token-signing/blob/master/host-windows/NativeSigner.cpp
      //https://github.com/open-eid/libdigidocpp/blob/master/src/crypto/WinSigner.cpp

      std::vector<uint8_t> data;

      const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
      if (arguments) {

        BCRYPT_PKCS1_PADDING_INFO padInfo;
        padInfo.pszAlgId = NCRYPT_SHA256_ALGORITHM;
        DWORD obtainKeyStrategy = CRYPT_ACQUIRE_PREFER_NCRYPT_KEY_FLAG;
        ALG_ID alg_id = CALG_SHA_256;
        LPCWSTR bcrypt_alg = BCRYPT_SHA256_ALGORITHM;

        auto algorithm_it = arguments->find(flutter::EncodableValue("algorithm"));
        if (algorithm_it != arguments->end()) {
          std::string alg = std::get<std::string>(algorithm_it->second);
          std::transform(alg.begin(), alg.end(), alg.begin(), [](unsigned char c) { return static_cast<unsigned char>(std::tolower(c)); });
          if (alg.find("sha-1") != std::string::npos || alg.find("sha1") != std::string::npos) {
            padInfo.pszAlgId = NCRYPT_SHA1_ALGORITHM;
            alg_id = CALG_SHA1;
            bcrypt_alg = BCRYPT_SHA1_ALGORITHM;
          }
          else if (alg.find("sha-256") != std::string::npos || alg.find("sha256") != std::string::npos) {
            padInfo.pszAlgId = NCRYPT_SHA256_ALGORITHM;
            alg_id = CALG_SHA_256;
            bcrypt_alg = BCRYPT_SHA256_ALGORITHM;
          }
          else if (alg.find("sha-384") != std::string::npos || alg.find("sha384") != std::string::npos) {
            padInfo.pszAlgId = NCRYPT_SHA384_ALGORITHM;
            alg_id = CALG_SHA_384;
            bcrypt_alg = BCRYPT_SHA384_ALGORITHM;
          }
          else {
            padInfo.pszAlgId = NCRYPT_SHA512_ALGORITHM;
            alg_id = CALG_SHA_512;
            bcrypt_alg = BCRYPT_SHA512_ALGORITHM;
          }
        }

        auto data_it = arguments->find(flutter::EncodableValue("data"));
        if (data_it != arguments->end()) {

          data = std::get<std::vector<uint8_t>>(data_it->second);

          std::vector<unsigned char> signature;

          DWORD flags = obtainKeyStrategy | CRYPT_ACQUIRE_COMPARE_KEY_FLAG;
          DWORD spec = 0;
          BOOL freeKeyHandle = false;
          HCRYPTPROV_OR_NCRYPT_KEY_HANDLE* handle = new HCRYPTPROV_OR_NCRYPT_KEY_HANDLE(0);
          BOOL gotKey = CryptAcquireCertificatePrivateKey(pCertContext, flags, 0, handle, &spec, &freeKeyHandle);
          if (!gotKey) {
            std::cout << "Error getting key context." << std::endl;
            result->Error("signing_error", "Error getting key context.");
            return;
          }

          auto deleter = [=](HCRYPTPROV_OR_NCRYPT_KEY_HANDLE* key) {
            if (!freeKeyHandle)
              return;
            if (spec == CERT_NCRYPT_KEY_SPEC)
              NCryptFreeObject(*key);
            else
              CryptReleaseContext(*key, 0);
          };
          std::unique_ptr<HCRYPTPROV_OR_NCRYPT_KEY_HANDLE, decltype(deleter)> key(handle, deleter);

          switch (spec)
          {
          case CERT_NCRYPT_KEY_SPEC:
          {
            // Calculate the hash
            // https://docs.microsoft.com/en-us/windows/win32/seccng/creating-a-hash-with-cng

            // Hash variables
            BCRYPT_ALG_HANDLE       hAlg = NULL;
            BCRYPT_HASH_HANDLE      hHash = NULL;
            NTSTATUS                status = STATUS_UNSUCCESSFUL;
            DWORD                   cbData = 0,
              cbHash = 0,
              cbHashObject = 0;
            PBYTE                   pbHashObject = NULL;
            PBYTE                   pbHash = NULL;

            //open an algorithm handle
            if (!NT_SUCCESS(status = BCryptOpenAlgorithmProvider(
              &hAlg,
              bcrypt_alg,
              NULL,
              0))) {
              std::cout << "Error in BCryptOpenAlgorithmProvider: " << status << std::endl;
              result->Error("signing_error", "Error in BCryptOpenAlgorithmProvider.");
              CleanBCryptHashObjects(hAlg, hHash, pbHashObject, pbHash);
              return;
            }

            //calculate the size of the buffer to hold the hash object
            if (!NT_SUCCESS(status = BCryptGetProperty(
              hAlg,
              BCRYPT_OBJECT_LENGTH,
              (PBYTE)&cbHashObject,
              sizeof(DWORD),
              &cbData,
              0))) {
              std::cout << "Error in BCryptGetProperty: " << status << std::endl;
              result->Error("signing_error", "Error in BCryptOpenAlgorithmProvider.");
              CleanBCryptHashObjects(hAlg, hHash, pbHashObject, pbHash);
              return;
            }

            //allocate the hash object on the heap
            pbHashObject = (PBYTE)HeapAlloc(GetProcessHeap(), 0, cbHashObject);
            if (NULL == pbHashObject) {
              std::cout << "memory allocation failed" << std::endl;
              result->Error("signing_error", "memory allocation failed.");
              CleanBCryptHashObjects(hAlg, hHash, pbHashObject, pbHash);
              return;
            }

            //calculate the length of the hash
            if (!NT_SUCCESS(status = BCryptGetProperty(
              hAlg,
              BCRYPT_HASH_LENGTH,
              (PBYTE)&cbHash,
              sizeof(DWORD),
              &cbData,
              0))) {
              std::cout << "Error in BCryptGetProperty: " << status << std::endl;
              result->Error("signing_error", "Error in BCryptOpenAlgorithmProvider.");
              CleanBCryptHashObjects(hAlg, hHash, pbHashObject, pbHash);
              return;
            }

            //allocate the hash buffer on the heap
            pbHash = (PBYTE)HeapAlloc(GetProcessHeap(), 0, cbHash);
            if (NULL == pbHash) {
              std::cout << "memory allocation failed" << std::endl;
              result->Error("signing_error", "memory allocation failed.");
              CleanBCryptHashObjects(hAlg, hHash, pbHashObject, pbHash);
              return;
            }

            //create a hash
            if (!NT_SUCCESS(status = BCryptCreateHash(
              hAlg,
              &hHash,
              pbHashObject,
              cbHashObject,
              NULL,
              0,
              0))) {
              std::cout << "Error in BCryptCreateHash: " << status << std::endl;
              result->Error("signing_error", "Error in BCryptOpenAlgorithmProvider.");
              CleanBCryptHashObjects(hAlg, hHash, pbHashObject, pbHash);
              return;
            }

            //hash some data
            if (!NT_SUCCESS(status = BCryptHashData(
              hHash,
              (PBYTE)data.data(),
              (ULONG)data.size(),
              0))) {
              std::cout << "Error in BCryptHashData: " << status << std::endl;
              result->Error("signing_error", "Error in BCryptOpenAlgorithmProvider.");
              CleanBCryptHashObjects(hAlg, hHash, pbHashObject, pbHash);
              return;
            }

            //close the hash
            if (!NT_SUCCESS(status = BCryptFinishHash(
              hHash,
              pbHash,
              cbHash,
              0))) {
              std::cout << "Error in BCryptFinishHash: " << status << std::endl;
              result->Error("signing_error", "Error in BCryptOpenAlgorithmProvider.");
              CleanBCryptHashObjects(hAlg, hHash, pbHashObject, pbHash);
              return;
            }

            // Sign the obtained hash

            DWORD size = 0;
            std::wstring algo(5, 0);
            if (!NT_SUCCESS(status = NCryptGetProperty(*key.get(), NCRYPT_ALGORITHM_GROUP_PROPERTY,
              PBYTE(algo.data()), DWORD((algo.size() + 1) * 2), &size, 0))) {
              std::cout << "Error in NCryptGetProperty with NCRYPT_ALGORITHM_GROUP_PROPERTY: " << status << std::endl;
              result->Error("signing_error", "Error in NCryptGetProperty with NCRYPT_ALGORITHM_GROUP_PROPERTY.");
              CleanBCryptHashObjects(hAlg, hHash, pbHashObject, pbHash);
              return;
            }

            algo.resize(size / 2 - 1);
            bool isRSA = algo == L"RSA";

            if (!NT_SUCCESS(status = NCryptSignHash(*key.get(), isRSA ? &padInfo : nullptr, pbHash, cbHash,
              nullptr, 0, LPDWORD(&size), BCRYPT_PAD_PKCS1))) {
              std::cout << "Error getting size in NCryptSignHash: " << status << std::endl;
              result->Error("signing_error", "Error getting size in NCryptSignHash.");
              CleanBCryptHashObjects(hAlg, hHash, pbHashObject, pbHash);
              return;
            }

            signature.resize(size);
            if (!NT_SUCCESS(status = NCryptSignHash(*key.get(), isRSA ? &padInfo : nullptr, pbHash, cbHash,
              signature.data(), DWORD(signature.size()), LPDWORD(&size), BCRYPT_PAD_PKCS1))) {
              std::cout << "Error in NCryptSignHash: " << status << std::endl;
              result->Error("signing_error", "Error in NCryptSignHash.");
              CleanBCryptHashObjects(hAlg, hHash, pbHashObject, pbHash);
              return;
            }

            break;
          }
          case AT_KEYEXCHANGE:
          case AT_SIGNATURE:
          {
            std::cout << "AT_SIGNATURE" << std::endl;

            HCRYPTHASH hash = 0;
            if (!CryptCreateHash(*key.get(), alg_id, 0, 0, &hash)) {
              std::cout << "CryptCreateHash failed." << std::endl;
              result->Error("signing_error", "CryptCreateHash failed.");
              return;
            }

            BYTE* pbMessage = (BYTE*)(data.data());  // Message to be signed
            DWORD cbMessage = (WORD)(data.size());  // Size of the message

            if (!CryptHashData(hash, pbMessage, cbMessage, 0)) {
              CryptDestroyHash(hash);
              std::cout << "Error during CryptHashData." << std::endl;
              result->Error("signing_error", "Error during CryptHashData.");
              return;
            }

            DWORD size = 0;
            if (!CryptSignHashW(hash, spec, nullptr, 0, nullptr, &size)) {
              CryptDestroyHash(hash);
              std::cout << "Error getting size in CryptSignHashW." << std::endl;
              result->Error("signing_error", "Error getting size in CryptSignHashW.");
              return;
            }

            signature.resize(size);
            if (!CryptSignHashW(hash, spec, nullptr, 0, LPBYTE(signature.data()), &size)) {
              CryptDestroyHash(hash);
              std::cout << "Error in CryptSignHashW." << std::endl;
              result->Error("signing_error", "Error in CryptSignHashW.");
              return;
            }

            CryptDestroyHash(hash);
            reverse(signature.begin(), signature.end());
            break;
          }
          default:
          {
            std::cout << "Incompatible key." << std::endl;
            result->Error("signing_error", "Incompatible key.");
            return;
          }
          }

          result->Success(flutter::EncodableValue(signature));
        }
      }
    }
    else {
      result->NotImplemented();
    }
  }

  void DigitalCertificatesPlugin::CleanUp() {
    // Clean up and free memory as needed.
    if (pCertContext) {
      CertFreeCertificateContext(pCertContext);
    }
    if (hCertStore) {
      CertCloseStore(hCertStore, CERT_CLOSE_STORE_CHECK_FLAG);
      hCertStore = NULL;
    }
  }

  void DigitalCertificatesPlugin::CleanBCryptHashObjects(BCRYPT_ALG_HANDLE hAlg, BCRYPT_HASH_HANDLE hHash, PBYTE pbHashObject, PBYTE pbHash) {
    if (hAlg) {
      BCryptCloseAlgorithmProvider(hAlg, 0);
    }
    if (hHash) {
      BCryptDestroyHash(hHash);
    }
    if (pbHashObject) {
      HeapFree(GetProcessHeap(), 0, pbHashObject);
    }
    if (pbHash) {
      HeapFree(GetProcessHeap(), 0, pbHash);
    }
  }
}  // namespace

void DigitalCertificatesPluginRegisterWithRegistrar(
  FlutterDesktopPluginRegistrarRef registrar) {
  // The plugin registrar owns the plugin, registered callbacks, etc., so must
  // remain valid for the life of the application.
  static auto* plugin_registrar = new flutter::PluginRegistrar(registrar);

  DigitalCertificatesPlugin::RegisterWithRegistrar(plugin_registrar);
}

