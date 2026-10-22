#!/bin/sh
HMDM_DIR=/opt/hmdm
TEMPLATE_DIR=$HMDM_DIR/templates
TOMCAT_DIR=/usr/local/tomcat
BASE_DIR=$TOMCAT_DIR/work
CACHE_DIR=$BASE_DIR/cache
PASSWORD=123456

for DIR in cache files plugins logs; do
   [ -d "$BASE_DIR/$DIR" ] || mkdir "$BASE_DIR/$DIR"
done

if [ ! -z "$LOCAL_IP" ]; then
    EXISTS=`grep $BASE_DOMAIN /etc/hosts`
    if [ -z "$EXISTS" ] || [ "$FORCE_RECONFIGURE" = "true" ]; then
        grep -v $BASE_DOMAIN /etc/hosts > /etc/hosts~
	cp /etc/hosts~ /etc/hosts
	echo "$LOCAL_IP $BASE_DOMAIN" >> /etc/hosts
	rm -f /etc/hosts~
    fi
fi

# ALL MDM: protocolo que os celulares e o navegador enxergam.
# Atrás de um proxy reverso com TLS, use PROTOCOL=http e PUBLIC_PROTOCOL=https.
PUBLIC_PROTOCOL=${PUBLIC_PROTOCOL:-$PROTOCOL}

HMDM_WAR="$(basename -- $HMDM_URL)"

if [ -f "$CACHE_DIR/$HMDM_WAR" ] && [ "$FORCE_RECONFIGURE" = "true" ]; then
    rm -f $CACHE_DIR/$HMDM_WAR
fi

if [ ! -f "$CACHE_DIR/$HMDM_WAR" ]; then
    if ! wget $DOWNLOAD_CREDENTIALS $HMDM_URL -O $CACHE_DIR/$HMDM_WAR; then
        echo "Failed to retrieve $HMDM_URL!"
        exit 1
    fi
fi

DEPLOYED_WAR_FILE=$TOMCAT_DIR/webapps/.deployed-war
if [ ! -f "$TOMCAT_DIR/webapps/ROOT.war" ] || [ "$FORCE_RECONFIGURE" = "true" ] || [ "$(cat $DEPLOYED_WAR_FILE 2>/dev/null)" != "$HMDM_WAR" ]; then
    cp $CACHE_DIR/$HMDM_WAR $TOMCAT_DIR/webapps/ROOT.war
    echo "$HMDM_WAR" > $DEPLOYED_WAR_FILE
fi

$HMDM_DIR/update-web-app-docker.sh

if [ ! -f "$BASE_DIR/log4j.xml" ] || [ "$FORCE_RECONFIGURE" = "true" ]; then
    cp $TEMPLATE_DIR/conf/log4j_template.xml $BASE_DIR/log4j-hmdm.xml
fi

if [ ! -d "$BASE_DIR/emails" ] || [ "$FORCE_RECONFIGURE" = "true" ]; then
    cp -r $TEMPLATE_DIR/emails $BASE_DIR/emails
fi

if [ ! -d $TOMCAT_DIR/conf/Catalina/localhost ]; then
    mkdir -p $TOMCAT_DIR/conf/Catalina/localhost
fi

if [ ! -f "$TOMCAT_DIR/conf/Catalina/localhost/ROOT.xml" ] || [ "$FORCE_RECONFIGURE" = "true" ]; then
    cat $TEMPLATE_DIR/conf/context_template.xml | sed "s|_SQL_HOST_|$SQL_HOST|g; s|_SQL_PORT_|$SQL_PORT|g; s|_SQL_BASE_|$SQL_BASE|g; s|_SQL_USER_|$SQL_USER|g; s|_SQL_PASS_|$SQL_PASS|g; s|_PROTOCOL_|$PUBLIC_PROTOCOL|g; s|_BASE_DOMAIN_|$BASE_DOMAIN|g; s|_SHARED_SECRET_|$SHARED_SECRET|g;" > $TOMCAT_DIR/conf/Catalina/localhost/ROOT.xml 
fi

for DIR in cache files plugins logs; do
   [ -d "$BASE_DIR/$DIR" ] || mkdir "$BASE_DIR/$DIR"
done

# ALL MDM: grava (ou atualiza) um parâmetro no ROOT.xml
ROOT_XML=$TOMCAT_DIR/conf/Catalina/localhost/ROOT.xml
set_param() {
    [ -z "$2" ] && return
    VALUE=$(printf '%s' "$2" | sed 's/&/\&amp;/g; s/"/\&quot;/g; s/</\&lt;/g')
    # Troca o parâmetro fora de comentários XML; se não existir, insere antes de </Context>
    PARAM_NAME="$1" PARAM_VALUE="$VALUE" awk '
        BEGIN { name = ENVIRON["PARAM_NAME"]; line = "    <Parameter name=\"" name "\" value=\"" ENVIRON["PARAM_VALUE"] "\"/>" }
        {
            rest = $0; open = incomment
            while (1) {
                if (open) { i = index(rest, "-->"); if (!i) break; rest = substr(rest, i + 3); open = 0 }
                else      { i = index(rest, "<!--"); if (!i) break; rest = substr(rest, i + 4); open = 1 }
            }
            active = !incomment && index($0, "<!--") == 0
            if (active && !done && index($0, "<Parameter name=\"" name "\"") > 0) { print line; done = 1; incomment = open; next }
            if (active && !done && index($0, "</Context>") > 0) { print line; done = 1 }
            incomment = open
            print
        }' "$ROOT_XML" > "$ROOT_XML.tmp" && cat "$ROOT_XML.tmp" > "$ROOT_XML" && rm -f "$ROOT_XML.tmp"
}
set_param base.url "$PUBLIC_PROTOCOL://$BASE_DOMAIN"
set_param hash.secret "$SHARED_SECRET"
set_param launcher.package "$AGENT_PKG"
set_param rebranding.name "$BRAND_NAME"
set_param rebranding.vendor.name "$BRAND_VENDOR"
set_param rebranding.vendor.link "$BRAND_LINK"
set_param rebranding.mobile.name "$AGENT_NAME"
# ALL MDM: e-mail (recuperação de senha). Só grava se SMTP_HOST estiver definido.
if [ ! -z "$SMTP_HOST" ]; then
    set_param smtp.host "$SMTP_HOST"
    set_param smtp.port "${SMTP_PORT:-465}"
    set_param smtp.ssl "${SMTP_SSL:-1}"
    set_param smtp.starttls "${SMTP_STARTTLS:-0}"
    set_param smtp.username "$SMTP_USER"
    set_param smtp.password "$SMTP_PASS"
    set_param smtp.from "${SMTP_FROM:-$SMTP_USER}"
fi
# ALL MDM: login único via Authentik (OIDC). Só grava se OIDC_ISSUER estiver definido.
if [ ! -z "$OIDC_ISSUER" ]; then
    set_param oidc.issuer "$OIDC_ISSUER"
    set_param oidc.client.id "$OIDC_CLIENT_ID"
    set_param oidc.client.secret "$OIDC_CLIENT_SECRET"
    set_param oidc.button.label "$OIDC_BUTTON_LABEL"
fi
if [ ! -z "$PROXY_ADDRESSES" ]; then
    set_param proxy.addresses "$PROXY_ADDRESSES"
    set_param proxy.ip.header "${PROXY_IP_HEADER:-X-Forwarded-For}"
fi

# ALL MDM: agente Android da ALL, servido pelo próprio painel
AGENT_FILE="$(basename -- $AGENT_URL)"
if [ ! -f "$BASE_DIR/files/$AGENT_FILE" ]; then
    if ! wget $AGENT_URL -O $BASE_DIR/files/$AGENT_FILE; then
        echo "Failed to retrieve $AGENT_URL!"
        rm -f $BASE_DIR/files/$AGENT_FILE
    fi
fi

if [ "$INSTALL_LANGUAGE" != "ru" ]; then
    INSTALL_LANGUAGE=en
fi

# ALL MDM: o init.sql é regerado a cada subida. O painel só o executa em banco vazio, então
# é seguro; e evita o bug original em que, a partir da 2ª subida, o init.sql ficava vazio e
# um banco recriado depois recebia só os padrões em russo.
if true; then
    cat $TEMPLATE_DIR/sql/hmdm_init.$INSTALL_LANGUAGE.sql | sed "s|_ADMIN_EMAIL_|$ADMIN_EMAIL|g; s|_HMDM_VERSION_|$CLIENT_VERSION|g; s|_HMDM_VARIANT_|$HMDM_VARIANT|g; s|_AGENT_PKG_|$AGENT_PKG|g; s|_AGENT_NAME_|$AGENT_NAME|g; s|_AGENT_VERSION_|$AGENT_VERSION|g; s|_AGENT_URL_|$PUBLIC_PROTOCOL://$BASE_DOMAIN/files/$AGENT_FILE|g" > $BASE_DIR/init1.sql
fi

FILES_TO_DOWNLOAD=$(grep https://h-mdm.com $BASE_DIR/init1.sql | awk '{ print $4 }' | sed "s/'//g; s/)//g; s/,//g")

cat $BASE_DIR/init1.sql | sed "s|https://h-mdm.com|$PUBLIC_PROTOCOL://$BASE_DOMAIN|g" > $BASE_DIR/init.sql
rm $BASE_DIR/init1.sql

cd $BASE_DIR/files
for FILE in $FILES_TO_DOWNLOAD; do
    FILENAME=$(basename $FILE)
    if [ ! -f "$BASE_DIR/files/$FILENAME" ]; then
	wget $FILE
    fi
done

# jks is always created from the certificates
if [ "$PROTOCOL" = "https" ]; then
    if [ "$HTTPS_LETSENCRYPT" = "true" ]; then
	HTTPS_CERT_PATH=/etc/letsencrypt/live/$BASE_DOMAIN
        echo "Looking for SSL keys in $HTTPS_CERT_PATH..."
	# If started by docker-compose, let's wait until certbot completes
	until [ -f $HTTPS_CERT_PATH/$HTTPS_PRIVKEY ]; do
            echo "Keys not found, waiting..."
	    sleep 5
        done
    fi

    openssl pkcs12 -export -out $TOMCAT_DIR/ssl/hmdm.p12 -inkey $HTTPS_CERT_PATH/$HTTPS_PRIVKEY -in $HTTPS_CERT_PATH/$HTTPS_CERT -certfile $HTTPS_CERT_PATH/$HTTPS_FULLCHAIN -password pass:$PASSWORD
    keytool -importkeystore -destkeystore $TOMCAT_DIR/ssl/hmdm.jks -srckeystore $TOMCAT_DIR/ssl/hmdm.p12 -srcstoretype PKCS12 -srcstorepass $PASSWORD -deststorepass $PASSWORD -noprompt    
fi

# Waiting for the database
until PGPASSWORD=$SQL_PASS psql -h "$SQL_HOST" -p "${SQL_PORT:-5432}" -U "$SQL_USER" -d "$SQL_BASE" -c '\q'; do
  echo "Waiting for the PostgreSQL database..."
  sleep 5
done

# Avoid delays due to an issue with a random number
cp /opt/java/openjdk/conf/security/java.security /tmp/java.security
cat /tmp/java.security | sed "s|securerandom.source=file:/dev/random|securerandom.source=file:/dev/urandom|g" > /opt/java/openjdk/conf/security/java.security
rm /tmp/java.security

catalina.sh run

#sleep 100000
