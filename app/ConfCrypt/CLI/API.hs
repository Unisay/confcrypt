module ConfCrypt.CLI.API (
    KeyAndConf(..),
    Conf(..),
    KeyProvider(..),
    AnyCommand(..),
    cliParser
) where

import ConfCrypt.Types (SchemaType(..))
import ConfCrypt.Commands (AddConfCrypt(..), EditConfCrypt(..), DeleteConfCrypt(..))

import Data.Monoid ((<>))
import Options.Applicative
import qualified Data.Text as T

data KeyAndConf = KeyAndConf {key :: FilePath, provider :: KeyProvider, conf :: FilePath}
    deriving (Eq, Show)
newtype Conf = Conf FilePath
    deriving (Eq, Show)

data AnyCommand
    = RC KeyAndConf
    | AC KeyAndConf AddConfCrypt
    | EC KeyAndConf EditConfCrypt
    | DC Conf DeleteConfCrypt
    | VC KeyAndConf
    | PC KeyAndConf
    | NC
    deriving (Eq, Show)

data KeyProvider
    = AWS
    | LocalRSA
    deriving (Eq, Show)

cliParser :: ParserInfo AnyCommand
cliParser = info (commandParser <**> helper) $
        fullDesc <>
        (header "confcrypt: a tool for sane configuration management") <>
        (footer "confcrypt's documentation and source is avaiable at <TODO fill me in>")


commandParser :: Parser AnyCommand
commandParser = hsubparser
    (
        command "add" add
        <>
        command "edit" edit
        <>
        command "delete" delete
        <>
        command "read" readConf
        <>
        command "validate" validate
        <>
        command "new" new
        <>
        command "export" export
    )

add :: ParserInfo AnyCommand
add = info ( AC <$> keyAndConf <*> (AddConfCrypt <$> onlyName <*> onlyValue <*> onlyType))
           (progDesc "Add a new parameter to the configuration file. New parameters are added to the end of the file." <>
            fullDesc)

edit :: ParserInfo AnyCommand
edit = info ( EC <$> keyAndConf <*> (EditConfCrypt <$> onlyName <*> onlyValue <*> onlyType))
           (progDesc "Modify an existing parameter in-place. This should preserve a clean diff." <>
            fullDesc)

delete :: ParserInfo AnyCommand
delete = info ( DC <$> getConf <*> (DeleteConfCrypt <$> onlyName))
           (progDesc "Removes an existing parameter from the configuration." <>
            fullDesc)

readConf :: ParserInfo AnyCommand
readConf = info ( RC <$> keyAndConf )
           (progDesc "Read in the provided config and decrypt it with the key. Results are printed to StdOut." <>
            fullDesc)

validate :: ParserInfo AnyCommand
validate = info ( VC <$> keyAndConf)
           (progDesc "Check that the configuration is self-consistent and obeys the confcrypt rules." <>
            fullDesc)

new :: ParserInfo AnyCommand
new  = info (pure NC)
            (progDesc "Produce a new boilerplate confcrypt file. This should be piped into your desired config." <>
             fullDesc)

export :: ParserInfo AnyCommand
export = info (PC <$> keyAndConf)
         (progDesc "Produce an export bash script that can be sourced to inject config variables into environment" <>
          fullDesc)

keyAndConf :: Parser KeyAndConf
keyAndConf =
    KeyAndConf <$>
        strOption (
            long "key" <>
            short 'k' <>
            metavar "KEY" <>
            help "The path to the private RSA key used to encrypt this file."
            ) <*>
        getProvider <*>
        onlyConf

getConf :: Parser Conf
getConf = Conf <$> onlyConf

onlyConf :: Parser FilePath
onlyConf = strArgument (metavar "CONFIG_FILE")

onlyName :: Parser T.Text
onlyName = strOption (
    long "name" <>
    short 'n' <>
    metavar "PARAMETER_NAME" <>
    help "The name of the configuration parameter. This must consist of consist solely of uppercase letters, digits, and the '_' (underscore) ASCII characters."
    )

onlyValue :: Parser T.Text
onlyValue = strOption (
    long "value" <>
    short 'v' <>
    metavar "PARAMETER_VALUE" <>
    help "The value to set in the config file. This can be any set of characters you want, but there may be issues with multi-byte code points in UTF-8."
    )

onlyType :: Parser SchemaType
onlyType =
      fromString <$> strOption (
        long "type" <>
        short 't' <>
        metavar "PARAMETER_TYPE" <>
        help "The associated type for the variable"
        )
    where
        fromString = read . (:) 'C'

getProvider :: Parser KeyProvider
getProvider = flag LocalRSA AWS (
    long "use-aws" <>
    help "Toggles whether the --key indicates an RSA keyfile or an AWS KMS key identifer"
    )
