{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}
module Handler.Home where

import Import
import qualified Data.Map as M
import qualified Data.Maybe as MB
import Database.Persist.MySQL (ConnectInfo(..), myConnInfo)
import Database.HDBC (execute, prepare, fetchAllRowsMap, SqlValue, fromSql)
import Database.HDBC.MySQL (Connection, MySQLConnectInfo(..),
                            defaultMySQLConnectInfo, connectMySQL)
import Yesod.Form.Bootstrap3 (BootstrapFormLayout (..), renderBootstrap3)
import Text.Julius (RawJS (..))

-- Define our data that will be used for creating the form.
data FileForm = FileForm
    { fileInfo :: FileInfo
    , fileDescription :: Text
    }

data TekaUser = TekaUser {
    tid :: Int64
  , ident :: Text
  , password :: Text
} deriving(Show, Eq)

-- This is a handler function for the GET request method on the HomeR
-- resource pattern. All of your resource patterns are defined in
-- config/routes
--
-- The majority of the code you will write in Yesod lives in these handler
-- functions. You can spread them across multiple files if you are so
-- inclined, or create a single monolithic file.
getHomeR :: Handler Html
getHomeR = do
    master <- getYesod
    (formWidget, formEnctype) <- generateFormPost sampleForm
    let submission = Nothing :: Maybe FileForm
        handlerName = "getHomeR" :: Text
        dbconf = myConnInfo $ appDatabaseConf $ appSettings master
    tekkaTeka <- liftIO $ getDBConn dbconf >>= getTekkatekaUsers
    $(logInfo) $ pack $ "=====> テカテカログ： " ++ show tekkaTeka
    defaultLayout $ do
        let (commentFormId, commentTextareaId, commentListId) = commentIds
        aDomId <- newIdent
        setTitle "Welcome To Yesod!"
        $(widgetFile "homepage")

getTekkatekaUsers :: Connection -> IO ([TekaUser])
getTekkatekaUsers con = do
    stm <- prepare con $ "SELECT u.* FROM user AS u UNION SELECT tu.* FROM tekateka_user AS tu"
    _ <- execute stm []
    rows <- fetchAllRowsMap stm
    return $ MB.catMaybes $ toTeka rows

toTeka :: [M.Map String SqlValue] -> [Maybe TekaUser]
toTeka rows = map (\m -> TekaUser
                    `liftM` (fromSql <$> M.lookup "id" m)
                    `ap` (decodeUtf8 . fromSql <$> M.lookup "ident" m)
                    `ap` (decodeUtf8 . fromSql <$> M.lookup "password" m)) rows

getDBConn :: ConnectInfo -> IO Connection
getDBConn dbconf = connectMySQL defaultMySQLConnectInfo {
                mysqlHost = connectHost dbconf,
                mysqlUser = connectUser dbconf,
                mysqlPassword = connectPassword dbconf,
                mysqlDatabase = connectDatabase dbconf,
                mysqlPort = (fromIntegral(connectPort dbconf) :: Int),
                mysqlUnixSocket = "/var/run/mysqld/mysqld.sock"
            }

sampleForm :: Form FileForm
sampleForm = renderBootstrap3 BootstrapBasicForm $ FileForm
    <$> fileAFormReq "Choose a file"
    <*> areq textField textSettings Nothing
    -- Add attributes like the placeholder and CSS classes.
    where textSettings = FieldSettings
            { fsLabel = "What's on the file?"
            , fsTooltip = Nothing
            , fsId = Nothing
            , fsName = Nothing
            , fsAttrs =
                [ ("class", "form-control")
                , ("placeholder", "File description")
                ]
            }

commentIds :: (Text, Text, Text)
commentIds = ("js-commentForm", "js-createCommentTextarea", "js-commentList")
