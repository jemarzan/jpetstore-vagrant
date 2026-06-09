#!/bin/bash
# ==============================================================================
# Tomcat Provisioning Script — JPetStore 6
# For: Vagrant VM (CentOS/RHEL-based)
# Usage: Add to Vagrantfile as: config.vm.provision "shell", path: "jpetstore-tomcat.sh"
# ==============================================================================

# ── CHANGE THESE BEFORE USE ───────────────────────────────────────────────────
TOMCAT_VERSION="9.0.96"
MAVEN_VERSION="3.9.16"             # FIX: must be 3.9.16+ for JPetStore master
JAVA_PACKAGE="java-21-openjdk"     # FIX: must be Java 21+ for JPetStore master
TOMCAT_INSTALL_DIR="/usr/local/tomcat"
MAVEN_INSTALL_DIR="/usr/local/maven"

APP_REPO="https://github.com/mybatis/jpetstore-6.git"
APP_BRANCH="master"

# ── DATABASE CONNECTION ───────────────────────────────────────────────────────
DB_HOST="192.168.56.15"
DB_PORT="3306"
DB_NAME="jpetstore"
DB_USER="jpetuser"
DB_PASS="jpet123"
# ─────────────────────────────────────────────────────────────────────────────

TOMCAT_URL="https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"
MAVEN_URL="https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.zip"
TOMCAT_DIR="apache-tomcat-${TOMCAT_VERSION}"

echo "##################################################"
echo "   JPetStore 6 — Tomcat Provisioning Started"
echo "##################################################"

# -----------------------------------------------------------------------------
# STEP 1 — Install Java 21 and dependencies
# -----------------------------------------------------------------------------
echo "[1/7] Installing Java 21 and tools..."
sudo dnf -y install "${JAVA_PACKAGE}" "${JAVA_PACKAGE}-devel"
sudo dnf -y install git wget unzip zip

# Set Java 21 as default if multiple versions exist
sudo update-alternatives --set java \
  $(update-alternatives --list java | grep java-21) 2>/dev/null || true

JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
echo "      JAVA_HOME: ${JAVA_HOME}"
java -version

# -----------------------------------------------------------------------------
# STEP 2 — Download and install Tomcat
# -----------------------------------------------------------------------------
echo "[2/7] Downloading Tomcat ${TOMCAT_VERSION}..."

cd /tmp/
rm -f tomcatbin.tar.gz
rm -rf "${TOMCAT_DIR}"

wget -q "$TOMCAT_URL" -O tomcatbin.tar.gz

FILESIZE=$(stat -c%s tomcatbin.tar.gz)
echo "      Downloaded: ${FILESIZE} bytes"
if [[ $FILESIZE -lt 10000 ]]; then
  echo "ERROR: Tomcat download failed — file too small (possible 404)"
  exit 1
fi

tar xzf tomcatbin.tar.gz

if [[ ! -d "/tmp/${TOMCAT_DIR}" ]]; then
  echo "ERROR: /tmp/${TOMCAT_DIR} not found after extraction"
  ls /tmp/
  exit 1
fi

echo "      Extracted: /tmp/${TOMCAT_DIR}"

sudo rm -rf "$TOMCAT_INSTALL_DIR"
sudo cp -r /tmp/"${TOMCAT_DIR}" "$TOMCAT_INSTALL_DIR"

sudo useradd --shell /sbin/nologin tomcat 2>/dev/null || true
sudo chown -R tomcat:tomcat "$TOMCAT_INSTALL_DIR"
sudo chmod +x "$TOMCAT_INSTALL_DIR"/bin/*.sh

if [[ ! -f "${TOMCAT_INSTALL_DIR}/bin/catalina.sh" ]]; then
  echo "ERROR: catalina.sh not found after install!"
  exit 1
fi

echo "      Tomcat installed OK at ${TOMCAT_INSTALL_DIR}"

# -----------------------------------------------------------------------------
# STEP 3 — Create Tomcat systemd service
# -----------------------------------------------------------------------------
echo "[3/7] Creating Tomcat systemd service..."

sudo rm -f /etc/systemd/system/tomcat.service

sudo tee /etc/systemd/system/tomcat.service > /dev/null <<EOT
[Unit]
Description=Tomcat
After=network.target

[Service]
User=tomcat
Group=tomcat
WorkingDirectory=${TOMCAT_INSTALL_DIR}

Environment=JAVA_HOME=${JAVA_HOME}
Environment=CATALINA_PID=/tmp/tomcat.pid
Environment=CATALINA_HOME=${TOMCAT_INSTALL_DIR}
Environment=CATALINA_BASE=${TOMCAT_INSTALL_DIR}

ExecStart=${TOMCAT_INSTALL_DIR}/bin/catalina.sh run
ExecStop=${TOMCAT_INSTALL_DIR}/bin/shutdown.sh

RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOT

sudo systemctl daemon-reload
sudo systemctl start tomcat
sudo systemctl enable tomcat
sleep 5
sudo systemctl status tomcat --no-pager

# -----------------------------------------------------------------------------
# STEP 4 — Download Maven 3.9.16 and clone JPetStore
# -----------------------------------------------------------------------------
echo "[4/7] Downloading Maven ${MAVEN_VERSION} and cloning JPetStore..."
cd /tmp/
rm -f maven.zip
rm -rf apache-maven-"${MAVEN_VERSION}" jpetstore-6

wget -q "$MAVEN_URL" -O maven.zip
unzip -q maven.zip
sudo rm -rf "$MAVEN_INSTALL_DIR"
sudo cp -r apache-maven-"${MAVEN_VERSION}" "$MAVEN_INSTALL_DIR"

echo "      Maven version:"
"${MAVEN_INSTALL_DIR}"/bin/mvn -version

export MAVEN_OPTS="-Xmx512m"

git clone -b "$APP_BRANCH" "$APP_REPO" /tmp/jpetstore-6
cd /tmp/jpetstore-6

# -----------------------------------------------------------------------------
# STEP 5 — Patch applicationContext.xml: HSQLDB → MySQL
# -----------------------------------------------------------------------------
echo "[5/7] Patching app to connect to MySQL at ${DB_HOST}:${DB_PORT}..."

APP_CTX="src/main/webapp/WEB-INF/applicationContext.xml"

python3 - <<PYEOF
import re

with open("${APP_CTX}", "r") as f:
    content = f.read()

old_block = re.compile(
    r'<jdbc:embedded-database[^>]*>.*?</jdbc:embedded-database>',
    re.DOTALL
)

mysql_bean = """<bean id="dataSource"
      class="org.springframework.jdbc.datasource.DriverManagerDataSource">
  <property name="driverClassName" value="com.mysql.cj.jdbc.Driver"/>
  <property name="url"
    value="jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}?useSSL=false&amp;serverTimezone=UTC&amp;allowPublicKeyRetrieval=true"/>
  <property name="username" value="${DB_USER}"/>
  <property name="password" value="${DB_PASS}"/>
</bean>"""

new_content = old_block.sub(mysql_bean, content)

with open("${APP_CTX}", "w") as f:
    f.write(new_content)

print("      applicationContext.xml patched OK.")
PYEOF

python3 - <<PYEOF
with open("pom.xml", "r") as f:
    content = f.read()

mysql_dep = """
    <!-- MySQL JDBC Driver -->
    <dependency>
      <groupId>com.mysql</groupId>
      <artifactId>mysql-connector-j</artifactId>
      <version>8.3.0</version>
    </dependency>"""

if "mysql-connector-j" not in content:
    content = content.replace("</dependencies>", mysql_dep + "\n  </dependencies>", 1)
    with open("pom.xml", "w") as f:
        f.write(content)
    print("      mysql-connector-j added to pom.xml.")
else:
    print("      mysql-connector-j already present.")
PYEOF

# -----------------------------------------------------------------------------
# STEP 6 — Build and deploy WAR
# -----------------------------------------------------------------------------
echo "[6/7] Building with Maven (takes a few minutes)..."
cd /tmp/jpetstore-6
"${MAVEN_INSTALL_DIR}"/bin/mvn clean package -DskipTests

if [[ ! -f target/jpetstore.war ]]; then
  echo "ERROR: Maven build failed — jpetstore.war not found!"
  exit 1
fi

echo "      Deploying jpetstore.war..."
sudo systemctl stop tomcat
sleep 5

sudo rm -rf "${TOMCAT_INSTALL_DIR}"/webapps/jpetstore*
sudo cp target/jpetstore.war "${TOMCAT_INSTALL_DIR}"/webapps/jpetstore.war
sudo chown tomcat:tomcat "${TOMCAT_INSTALL_DIR}"/webapps/jpetstore.war

sudo systemctl start tomcat
sleep 15

# -----------------------------------------------------------------------------
# STEP 7 — Disable firewalld
# -----------------------------------------------------------------------------
echo "[7/7] Disabling firewalld..."
sudo systemctl stop firewalld
sudo systemctl disable firewalld
sudo systemctl restart tomcat

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo ""
echo "##################################################"
echo "   Provisioning Complete!"
echo "##################################################"
echo "  Tomcat  : ${TOMCAT_VERSION} → ${TOMCAT_INSTALL_DIR}"
echo "  Java    : ${JAVA_PACKAGE} (21)"
echo "  Maven   : ${MAVEN_VERSION}"
echo "  WAR     : jpetstore.war"
echo "  DB      : ${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
echo "##################################################"
echo ""
echo "  http://192.168.56.12:8080/jpetstore  (direct)"
echo "  http://192.168.56.11/jpetstore       (via Nginx)"
echo "##################################################"
