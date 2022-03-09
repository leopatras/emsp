--small webserver for internal test
OPTIONS
SHORT CIRCUIT
IMPORT com
IMPORT os
IMPORT util
DEFINE m_htport INT
DEFINE m_owndir STRING
DEFINE m_showallheaders STRING
DEFINE m_isMac INT
DEFINE _opt_kiosk_mode BOOLEAN

MAIN
  DEFINE i INT
  DEFINE req com.HTTPServiceRequest
  DEFINE text, url, path, fname, pre, arg STRING
  CONSTANT htmlExt="html"
  LET m_isMac = NULL
  LET arg=arg_val(1)
  IF NOT os.Path.exists(arg) OR NOT htmlExt.equals(os.Path.extension(arg)) THEN
    DISPLAY "usage: fglrun miniws <htmlfile>"
    EXIT PROGRAM 1
  END IF
  LET m_owndir = os.Path.fullPath(os.Path.dirName(arg_val(0)))
  LET m_showallheaders = fgl_getenv("SHOWALLHEADERS")
  LET m_htport = findFreeServerPort(9100, 9300, FALSE)
  CALL fgl_setenv("FGLAPPSERVER", m_htport)
  DISPLAY "miniws FGLAPPSERVER is:", fgl_getenv("FGLAPPSERVER")
  --do I need this option?
  CALL com.WebServiceEngine.SetOption("server_readwritetimeout", -1)
  CALL com.WebServiceEngine.Start()
  LET pre = SFMT("http://localhost:%1/", m_htport)
  --massage the ar
  LET url = SFMT("%1%2?t=%3", pre, arg, util.Strings.urlEncode(CURRENT))
  --LET url=sfmt("%1bart.png",pre)
  DISPLAY "url:", url
  CALL openBrowser(url)
  WHILE TRUE
    LET req = com.WebServiceEngine.GetHTTPServiceRequest(-1)
    IF req IS NULL THEN
      DISPLAY "ERROR: getHTTPServiceRequest timed out (60 seconds). Exiting."
      EXIT WHILE
    ELSE
      LET url = req.getUrl()
      DISPLAY "url:", url
&ifndef COM_HAS_URLPATH
      LET path = getUrlPath(url)
&else
      LET path = req.getUrlPath()
&endif
      DISPLAY "miniws path:", path, ",", req.getMethod()
      IF m_showallheaders THEN
        FOR i = 1 TO req.getRequestHeaderCount()
          DISPLAY SFMT("  HEADER %1:%2",
              req.getRequestHeaderName(i), req.getRequestHeaderValue(i))
        END FOR
      END IF
      CASE
        WHEN path = "/index.html"
          LET text = "<!DOCTYPE html><html><body>Hello</body></html>"
          CALL setContentType(req, "text/html")
          CALL req.sendTextResponse(200, NULL, text)
        WHEN path = "/text"
          CALL setContentType(req, "text/plain")
          CALL req.sendTextResponse(200, NULL, "A text")
        WHEN path = "/exit"
          CALL setContentType(req, "text/plain")
          CALL req.sendTextResponse(200, NULL, "Exit seen")
          EXIT WHILE
        WHEN path = "/bart.png"
          CALL processFile(req, "bart.png")
        WHEN path.getIndexOf("/", 1) == 1
          LET fname = path.subString(2, path.getLength())
          CALL processFile(req, fname)
        OTHERWISE
          DISPLAY "  404 Not Found:", url
          CALL req.sendTextResponse(404, NULL, SFMT("URL:%1 not found", url))
      END CASE
    END IF
  END WHILE
  DISPLAY "miniws ended"
END MAIN

FUNCTION getUrlPath(url)
  DEFINE url STRING
  DEFINE idx INT
  LET idx = url.getIndexOf("://", 1)
  IF idx > 0 THEN --remove scheme
    LET url = url.subString(idx + 3, url.getLength())
  END IF
  LET idx = url.getIndexOf("/", 1)
  IF idx > 0 THEN --remove host
    LET url = url.subString(idx, url.getLength())
  END IF
  LET idx = url.getIndexOf("?", 1)
  IF idx > 0 THEN --remove query
    LET url = url.subString(1, idx - 1)
  END IF
  RETURN url
END FUNCTION

FUNCTION setCrossBlaBla(req com.HttpServiceRequest)
  --make SharedArray buffer working
  CALL req.setResponseHeader("Cross-Origin-Opener-Policy", "same-origin")
  CALL req.setResponseHeader("Cross-Origin-Embedder-Policy", "require-corp")
END FUNCTION

FUNCTION processFile(req, fname)
  DEFINE req com.HTTPServiceRequest
  DEFINE fname, ct, ext STRING
  LET ext = downshift(os.Path.extension(fname))
  IF NOT os.Path.exists(fname) THEN
    DISPLAY "  404 Not Found:", fname
    CALL req.sendTextResponse(404, NULL, SFMT("File:%1 not found", fname))
    RETURN
  END IF
  CASE
    WHEN ext == "html" OR ext == "css" OR ext == "js"
      CASE
        WHEN ext == "html"
          LET ct = "text/html"
          CALL setCrossBlaBla(req)
        WHEN ext == "js"
          LET ct = "application/x-javascript"
          CALL setCrossBlaBla(req)
        WHEN ext == "css"
          LET ct = "text/css"
      END CASE
      CALL req.setResponseCharset("UTF-8")
      CALL setContentType(req, ct)
      DISPLAY "  200 OK:", fname
      CALL req.sendTextResponse(200, NULL, readTextFile(fname))
    OTHERWISE
      CASE
        WHEN ext == "gif"
          LET ct = "image/gif"
        WHEN ext == "png"
          LET ct = "image/png"
        WHEN ext == "jpg"
          LET ct = "image/jpeg"
        WHEN ext == "jpeg"
          LET ct = "image/jpeg"
        WHEN ext == "woff"
          LET ct = "application/font-woff"
        WHEN ext == "ttf"
          LET ct = "application/octet-stream"
      END CASE
      CALL setContentType(req, ct)
      DISPLAY "  200 OK:", fname
      CALL req.sendDataResponse(200, NULL, readBlob(fname))
  END CASE
END FUNCTION

FUNCTION setContentType(req, ct)
  DEFINE req com.HTTPServiceRequest
  DEFINE ct STRING
  IF ct IS NOT NULL THEN
    CALL req.setResponseHeader("Content-Type", ct)
  END IF
  CALL req.setResponseHeader("Cache-Control", "no-cache")
  CALL req.setResponseHeader("Expires", "-1")
  CALL req.setResponseHeader("Pragma", "no-cache")
  CALL req.setResponseHeader("Access-Control-Allow-Origin", "*")
END FUNCTION

FUNCTION readTextFile(fname)
  DEFINE fname, res STRING
  DEFINE t TEXT
  LOCATE t IN FILE fname
  LET res = t
  RETURN res
END FUNCTION

FUNCTION readBlob(fname)
  DEFINE fname STRING
  DEFINE blob BYTE
  LOCATE blob IN FILE fname
  RETURN blob
END FUNCTION

FUNCTION openBrowser(url)
  DEFINE url, cmd, browser, pre, lbrowser, defbrowser STRING
  CALL log(SFMT("openBrowser url:%1", url))
  IF fgl_getenv("SLAVE") IS NOT NULL THEN
    CALL log("gdcm SLAVE set,return")
    RETURN
  END IF
  LET browser = fgl_getenv("BROWSER")
  DISPLAY "browser:", browser
  CASE
    WHEN browser IS NOT NULL AND browser <> "default" AND browser <> "standard"
      IF browser == "gdcm" THEN --TODO: gdcm
        CASE
          WHEN isMac()
            LET browser = "./gdcm.app/Contents/MacOS/gdcm"
          WHEN isWin()
            LET browser = ".\\gdcm.exe"
          OTHERWISE
            LET browser = "./gdcm"
        END CASE
      END IF
      CASE
        WHEN isMac() AND browser <> "./gdcm.app/Contents/MacOS/gdcm"
          IF browser == "chrome" OR browser == "Google Chrome" THEN
            LET cmd = getMacChromeCmd(url)
          ELSE
            LET cmd = SFMT("open -a %1 '%2'", quote(browser), url)
          END IF
        WHEN isWin()
          LET lbrowser = browser.toLowerCase()
          --no path separator and no .exe given: we use start
          IF browser.getIndexOf("\\", 1) == 0
              AND lbrowser.getIndexOf(".exe", 1) == 0 THEN
            CASE
              WHEN (browser == "edge"
                  OR browser == "msedge"
                  OR browser == "chrome")
                LET cmd = getWinEdgeChromeCmd(browser, url)
              OTHERWISE
                LET pre = "start "
            END CASE
          END IF
          IF cmd IS NULL THEN
            LET cmd = SFMT('%1%2 %3', pre, quote(browser), winQuoteUrl(url))
          END IF
        OTHERWISE --Unix
          LET cmd = SFMT("%1 '%2'", quote(browser), url)
      END CASE
    OTHERWISE --standard browser
      CASE
        WHEN isWin()
          LET defbrowser = getWinDefaultBrowser()
          CASE
            WHEN defbrowser == "edge" OR defbrowser == "chrome"
              LET cmd = getWinEdgeChromeCmd(defbrowser, url)
            OTHERWISE
              LET cmd = SFMT("start %1", winQuoteUrl(url))
          END CASE
        WHEN isMac()
          IF getMacDefaultBrowser() == "chrome" THEN
            LET cmd = getMacChromeCmd(url)
          ELSE
            LET cmd = SFMT("open '%1'", url)
          END IF
        OTHERWISE --assume kinda linux
          LET cmd = SFMT("xdg-open '%1'", url)
      END CASE
  END CASE
  CALL log(SFMT("openBrowser cmd:%1", cmd))
  RUN cmd WITHOUT WAITING
END FUNCTION

FUNCTION log(s STRING)
  DISPLAY s
END FUNCTION

FUNCTION isWin()
  RETURN fgl_getenv("WINDIR") IS NOT NULL
END FUNCTION

FUNCTION isMac()
  IF m_isMac IS NULL THEN
    LET m_isMac = isMacInt()
  END IF
  RETURN m_isMac
END FUNCTION

FUNCTION isMacInt()
  DEFINE arr DYNAMIC ARRAY OF STRING
  IF NOT isWin() THEN
    CALL file_get_output("uname", arr)
    IF arr.getLength() < 1 THEN
      RETURN FALSE
    END IF
    IF arr[1] == "Darwin" THEN
      RETURN TRUE
    END IF
  END IF
  RETURN FALSE
END FUNCTION

FUNCTION file_get_output(program, arr)
  DEFINE program, linestr STRING
  DEFINE arr DYNAMIC ARRAY OF STRING
  DEFINE mystatus, idx INTEGER
  DEFINE c base.Channel
  LET c = base.Channel.create()
  WHENEVER ERROR CONTINUE
  CALL c.openPipe(program, "r")
  LET mystatus = status
  WHENEVER ERROR STOP
  IF mystatus THEN
    CALL myErr(SFMT("program:%1, error:%2", program, err_get(mystatus)))
  END IF
  CALL arr.clear()
  WHILE (linestr := c.readLine()) IS NOT NULL
    LET idx = idx + 1
    --DISPLAY "LINE ",idx,"=",linestr
    LET arr[idx] = linestr
  END WHILE
  CALL c.close()
END FUNCTION

FUNCTION findFreeServerPort(start, end, local)
  DEFINE start, end, local, freeport INT
  DEFINE ch base.Channel
  DEFINE i INT
  LET ch = base.Channel.create()
  FOR i = start TO end
    TRY
      CALL ch.openServerSocket(IIF(local, "127.0.0.1", NULL), i, "u")
      LET freeport = i
      EXIT FOR
    CATCH
      DISPLAY SFMT("can't bind port %1:%2", i, err_get(status))
    END TRY
  END FOR
  IF freeport > 0 THEN
    CALL ch.close()
    DISPLAY "found free port:", freeport
    RETURN freeport
  END IF
  CALL myErr(SFMT("Can't find free port in the range %1-%2", start, end))
  RETURN -1
END FUNCTION

FUNCTION getMacChromeCmd(url STRING)
  CONSTANT CHROME = "Google Chrome"
  DEFINE cmd STRING
  IF fgl_getenv("KIOSK") IS NOT NULL THEN
    LET cmd =
        SFMT("open -n -a %1 --args '--app=%2' '--force-devtools-available' '--no-default-browser-check'",
            quote(CHROME), url)
  ELSE
    LET cmd = SFMT("open -a %1  '%2'", quote(CHROME), url)
  END IF
  RETURN cmd
END FUNCTION

FUNCTION already_quoted(path)
  DEFINE path, first, last STRING
  LET first = NVL(path.getCharAt(1), "NULL")
  LET last = NVL(path.getCharAt(path.getLength()), "NULL")
  IF isWin() THEN
    RETURN (first == '"' AND last == '"')
  END IF
  RETURN (first == "'" AND last == "'") OR (first == '"' AND last == '"')
END FUNCTION

FUNCTION quote(path)
  DEFINE path STRING
  IF path.getIndexOf(" ", 1) > 0 THEN
    IF NOT already_quoted(path) THEN
      LET path = '"', path, '"'
    END IF
  ELSE
    IF already_quoted(path) AND isWin() THEN --remove quotes(Windows)
      LET path = path.subString(2, path.getLength() - 1)
    END IF
  END IF
  RETURN path
END FUNCTION

FUNCTION getWinEdgeChromeCmd(browser STRING, url STRING)
  LET browser = IIF(browser == "edge", "msedge", browser)
  IF _opt_kiosk_mode THEN
    RETURN SFMT("start %1 --new-window --app=%2", browser, winQuoteUrl(url))
  ELSE
    RETURN SFMT("start %1 %2", browser, winQuoteUrl(url))
  END IF
END FUNCTION

FUNCTION winQuoteUrl(url STRING) RETURNS STRING
  LET url = replace(url, "%", "^%")
  LET url = replace(url, "&", "^&")
  RETURN url
END FUNCTION

FUNCTION replace(src STRING, oldStr STRING, newString STRING)
  DEFINE b base.StringBuffer
  LET b = base.StringBuffer.create()
  CALL b.append(src)
  CALL b.replace(oldStr, newString, 0)
  RETURN b.toString()
END FUNCTION

FUNCTION getWinDefaultBrowser() RETURNS STRING
  DEFINE cmd, res, err, ext STRING
  DEFINE sz_idx, q_idx1, q_idx2 INT
  DEFINE success BOOLEAN
  --first try Windows 10
  LET cmd =
      "reg query HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Windows\\Shell\\Associations\\URLAssociations\\http\\UserChoice /v ProgID"
  CALL getProgramOutputWithErr(cmd) RETURNING res, err
  IF err IS NULL THEN
    LET sz_idx = res.getIndexOf("REG_SZ", 1)
    IF sz_idx > 0 THEN
      LET res = res.subString(sz_idx + 6, res.getLength())
      LET res = trimWhiteSpaceAndLower(res)
      LET success = TRUE
    END IF
  ELSE --older Windows
    LET cmd = "reg query HKEY_CLASSES_ROOT\\http\\shell\\open\\command /ve"
    CALL getProgramOutputWithErr(cmd) RETURNING res, err
    IF err IS NULL THEN
      LET sz_idx = res.getIndexOf("REG_SZ", 1)
      IF sz_idx > 0 THEN
        LET res = res.subString(sz_idx + 6, res.getLength())
        --remove '"' from the path
        --it's something like '"C:\Program Files\Microsoft\Edge\Application\msedge.exe"' ...
        LET q_idx1 = res.getIndexOf('"', 1)
        IF q_idx1 > 0 THEN
          LET q_idx2 = res.getIndexOf('"', q_idx1 + 1)
          IF q_idx2 > 0 THEN
            LET res = res.subString(q_idx1 + 1, q_idx2 - 1)
            LET res = os.Path.baseName(res)
            LET ext = os.Path.extension(res)
            IF ext IS NOT NULL THEN
              LET res = res.subString(1, res.getLength() - ext.getLength() - 1)
            END IF
            LET res = res.toLowerCase()
            --and the wanted result would be "msedge"
            LET success = TRUE
          END IF
        END IF
      END IF
    END IF
  END IF
  CALL log(SFMT("getWinDefaultBrowser res:'%1',success:%2", res, success))
  CASE
    WHEN NOT success
      RETURN "none"
    WHEN res.getIndexOf("firefox", 1) > 0
      RETURN "firefox"
    WHEN res.getIndexOf("msedge", 1) > 0
      RETURN "edge"
    WHEN res.getIndexOf("chrome", 1) > 0
      RETURN "chrome"
  END CASE
  RETURN res
END FUNCTION

--see https://stackoverflow.com/questions/32458095/how-can-i-get-the-default-browser-name-in-bash-script-on-mac-os-x
FUNCTION getMacDefaultBrowser()
  CONSTANT PBUDDY = "/usr/libexec/PlistBuddy"
  DEFINE plist, cmd, result, err, browser STRING
  DEFINE cnt, lastDot INT
  LET browser = "none"
  LET plist =
      os.Path.join(
          fgl_getenv("HOME"),
          "Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist")
  IF NOT os.Path.exists(plist) THEN
    RETURN browser
  END IF
  WHILE TRUE
    LET cmd =
        SFMT('%1 -c "Print LSHandlers:%2:LSHandlerURLScheme" %3',
            PBUDDY, cnt, quote(plist))
    CALL getProgramOutputWithErr(cmd) RETURNING result, err
    IF err IS NOT NULL THEN
      DISPLAY SFMT("Can't run:%1,err:%2", cmd, err)
      EXIT WHILE
    END IF
    IF result == "http" OR result == "https" THEN
      LET cmd =
          SFMT('%1 -c "Print LSHandlers:%2:LSHandlerRoleAll" %3',
              PBUDDY, cnt, quote(plist))
      CALL getProgramOutputWithErr(cmd) RETURNING result, err
      IF err IS NULL THEN
        --cut last entry from "com.apple.safari" or "com.google.chrome"
        LET lastDot = lastIndexOf(result, ".")
        IF lastDot > 0 THEN
          LET browser = result.subString(lastDot + 1, result.getLength())
        END IF
      END IF
      EXIT WHILE
    END IF
    LET cnt = cnt + 1
  END WHILE
  RETURN browser
END FUNCTION

FUNCTION printStderr(errstr STRING)
  DEFINE ch base.Channel
  LET ch = base.Channel.create()
  CALL ch.openFile("<stderr>", "w")
  CALL ch.writeLine(errstr)
  CALL ch.close()
END FUNCTION

FUNCTION myErr(errstr STRING)
  CALL printStderr(
      SFMT("ERROR:%1 stack:\n%2", errstr, base.Application.getStackTrace()))
  EXIT PROGRAM 1
END FUNCTION

FUNCTION lastIndexOf(s STRING, sub STRING)
  DEFINE startpos, idx, lastidx INT
  LET startpos = 1
  WHILE (idx := s.getIndexOf(sub, startpos)) > 0
    LET lastidx = idx
    LET startpos = idx + 1
  END WHILE
  RETURN lastidx
END FUNCTION

FUNCTION getProgramOutputWithErr(cmd STRING) RETURNS(STRING, STRING)
  DEFINE cmdOrig, tmpName, errStr STRING
  DEFINE txt TEXT
  DEFINE ret STRING
  DEFINE code INT
  LET cmdOrig = cmd
  LET tmpName = makeTempName()
  LET cmd = cmd, ">", tmpName, " 2>&1"
  --DISPLAY "run:", cmd
  RUN cmd RETURNING code
  --DISPLAY "code:", code
  LOCATE txt IN FILE tmpName
  LET ret = txt
  CALL os.Path.delete(tmpName) RETURNING status
  IF code THEN
    LET errStr = ",\n  output:", ret
    CALL os.Path.delete(tmpName) RETURNING code
  ELSE
    --remove \r\n
    IF ret.getCharAt(ret.getLength()) == "\n" THEN
      LET ret = ret.subString(1, ret.getLength() - 1)
    END IF
    IF ret.getCharAt(ret.getLength()) == "\r" THEN
      LET ret = ret.subString(1, ret.getLength() - 1)
    END IF
  END IF
  RETURN ret, errStr
END FUNCTION

#+computes a temporary file name
FUNCTION makeTempName()
  DEFINE tmpDir, tmpName, sbase, curr STRING
  DEFINE sb base.StringBuffer
  DEFINE i INT
  IF isWin() THEN
    LET tmpDir = fgl_getenv("TEMP")
  ELSE
    LET tmpDir = "/tmp"
  END IF
  LET curr = CURRENT
  LET sb = base.StringBuffer.create()
  CALL sb.append(curr)
  CALL sb.replace(" ", "_", 0)
  CALL sb.replace(":", "_", 0)
  CALL sb.replace(".", "_", 0)
  CALL sb.replace("-", "_", 0)
  LET sbase = SFMT("fgl_%1_%2", fgl_getpid(), sb.toString())
  LET sbase = os.Path.join(tmpDir, sbase)
  FOR i = 1 TO 10000
    LET tmpName = SFMT("%1%2.tmp", sbase, i)
    IF NOT os.Path.exists(tmpName) THEN
      RETURN tmpName
    END IF
  END FOR
  CALL myErr("makeTempName:Can't allocate a unique name")
  RETURN NULL
END FUNCTION

FUNCTION trimWhiteSpace(s STRING)
  LET s = s.trim()
  LET s = replace(s, "\n", "")
  LET s = replace(s, "\r", "")
  RETURN s
END FUNCTION

FUNCTION trimWhiteSpaceAndLower(s STRING)
  LET s = trimWhiteSpace(s)
  LET s = s.toLowerCase()
  RETURN s
END FUNCTION
