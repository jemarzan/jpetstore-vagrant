#!/bin/bash
# =============================================================================
# MySQL / MariaDB Provisioning Script — JPetStore 6
# For: Vagrant VM (CentOS/RHEL-based)
# Usage: Add to Vagrantfile as: config.vm.provision "shell", path: "jpetstore-mysql.sh"
# =============================================================================

# ── CHANGE THESE BEFORE USE ──────────────────────────────────────────────────
DB_ROOT_PASS='root123'         # Root password for MariaDB
DB_NAME='jpetstore'            # JPetStore database name
DB_USER='jpetuser'             # App database user
DB_USER_PASS='jpet123'         # App database user password

APP_REPO='https://github.com/mybatis/jpetstore-6.git'
APP_BRANCH='master'
# ─────────────────────────────────────────────────────────────────────────────

echo "##################################################"
echo "   JPetStore 6 — MariaDB Provisioning Started"
echo "##################################################"

# -----------------------------------------------------------------------------
# STEP 1 — System update & install dependencies
# -----------------------------------------------------------------------------
echo "[1/7] Updating system and installing packages..."
sudo yum update -y
sudo yum install -y epel-release
sudo yum install -y git zip unzip mariadb-server

# -----------------------------------------------------------------------------
# STEP 2 — Start and enable MariaDB
# -----------------------------------------------------------------------------
echo "[2/7] Starting MariaDB service..."
sudo systemctl start mariadb
sudo systemctl enable mariadb

# -----------------------------------------------------------------------------
# STEP 3 — Secure the root account
# -----------------------------------------------------------------------------
echo "[3/7] Securing root account..."

sudo mysqladmin -u root password "$DB_ROOT_PASS"
sudo mysql -u root -p"$DB_ROOT_PASS" -e "DELETE FROM mysql.user WHERE User='';"
sudo mysql -u root -p"$DB_ROOT_PASS" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
sudo mysql -u root -p"$DB_ROOT_PASS" -e "DROP DATABASE IF EXISTS test;"
sudo mysql -u root -p"$DB_ROOT_PASS" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
sudo mysql -u root -p"$DB_ROOT_PASS" -e "FLUSH PRIVILEGES;"

# -----------------------------------------------------------------------------
# STEP 4 — Create JPetStore database and user
# -----------------------------------------------------------------------------
echo "[4/7] Creating database '${DB_NAME}' and user '${DB_USER}'..."

sudo mysql -u root -p"$DB_ROOT_PASS" -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -u root -p"$DB_ROOT_PASS" -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_USER_PASS}';"
sudo mysql -u root -p"$DB_ROOT_PASS" -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%' IDENTIFIED BY '${DB_USER_PASS}';"
sudo mysql -u root -p"$DB_ROOT_PASS" -e "FLUSH PRIVILEGES;"

# -----------------------------------------------------------------------------
# STEP 5 — Clone JPetStore repo
# -----------------------------------------------------------------------------
echo "[5/7] Cloning JPetStore repo..."
cd /tmp/
rm -rf jpetstore-6
git clone -b "$APP_BRANCH" "$APP_REPO" jpetstore-6

# -----------------------------------------------------------------------------
# STEP 5b — Import MySQL-native schema directly
# FIX: Skip the HSQLDB schema files entirely — they use HSQLDB-only syntax
#      (CACHED TABLE, IDENTITY, LONGVARCHAR) that breaks in MariaDB even after
#      sed patching. We write a clean MySQL-native schema instead.
# -----------------------------------------------------------------------------
echo "[6/7] Creating MySQL-native schema and importing seed data..."

sudo mysql -u root -p"$DB_ROOT_PASS" "$DB_NAME" << 'SQLEOF'

-- Drop tables in reverse FK order (safe re-run)
DROP TABLE IF EXISTS ORDERSTATUS;
DROP TABLE IF EXISTS LINEITEM;
DROP TABLE IF EXISTS ORDERS;
DROP TABLE IF EXISTS INVENTORY;
DROP TABLE IF EXISTS ITEM;
DROP TABLE IF EXISTS PRODUCT;
DROP TABLE IF EXISTS CATEGORY;
DROP TABLE IF EXISTS BANNERDATA;
DROP TABLE IF EXISTS PROFILE;
DROP TABLE IF EXISTS ACCOUNT;
DROP TABLE IF EXISTS SIGNON;
DROP TABLE IF EXISTS SEQUENCE;

-- Signon table
CREATE TABLE SIGNON (
  USERNAME   VARCHAR(25)  NOT NULL,
  PASSWORD   VARCHAR(25)  NOT NULL,
  PRIMARY KEY (USERNAME)
);

-- Account table
CREATE TABLE ACCOUNT (
  USERID        VARCHAR(80)  NOT NULL,
  EMAIL         VARCHAR(80)  NOT NULL,
  FIRSTNAME     VARCHAR(80)  NOT NULL,
  LASTNAME      VARCHAR(80)  NOT NULL,
  STATUS        VARCHAR(2),
  ADDR1         VARCHAR(80),
  ADDR2         VARCHAR(40),
  CITY          VARCHAR(80),
  STATE         VARCHAR(80),
  ZIP           VARCHAR(20),
  COUNTRY       VARCHAR(20),
  PHONE         VARCHAR(80),
  PRIMARY KEY (USERID)
);

-- Profile table
CREATE TABLE PROFILE (
  USERID        VARCHAR(80)  NOT NULL,
  LANGPREF      VARCHAR(80)  NOT NULL,
  FAVCATEGORY   VARCHAR(30),
  MYLISTOPT     INT,
  BANNEROPT     INT,
  PRIMARY KEY (USERID)
);

-- Banner data table
CREATE TABLE BANNERDATA (
  FAVCATEGORY   VARCHAR(80)  NOT NULL,
  BANNERNAME    VARCHAR(255),
  PRIMARY KEY (FAVCATEGORY)
);

-- Category table
CREATE TABLE CATEGORY (
  CATID   VARCHAR(10)  NOT NULL,
  NAME    VARCHAR(80),
  DESCN   TEXT,
  PRIMARY KEY (CATID)
);

-- Product table
CREATE TABLE PRODUCT (
  PRODUCTID   VARCHAR(10)  NOT NULL,
  CATEGORY    VARCHAR(10)  NOT NULL,
  NAME        VARCHAR(80),
  DESCN       TEXT,
  PRIMARY KEY (PRODUCTID),
  FOREIGN KEY (CATEGORY) REFERENCES CATEGORY (CATID)
);

-- Item table
CREATE TABLE ITEM (
  ITEMID      VARCHAR(10)    NOT NULL,
  PRODUCTID   VARCHAR(10)    NOT NULL,
  LISTPRICE   DECIMAL(10,2),
  UNITCOST    DECIMAL(10,2),
  SUPPLIER    INT,
  STATUS      VARCHAR(2),
  ATTR1       VARCHAR(80),
  ATTR2       VARCHAR(80),
  ATTR3       VARCHAR(80),
  ATTR4       VARCHAR(80),
  ATTR5       VARCHAR(80),
  PRIMARY KEY (ITEMID),
  FOREIGN KEY (PRODUCTID) REFERENCES PRODUCT (PRODUCTID)
);

-- Inventory table
CREATE TABLE INVENTORY (
  ITEMID   VARCHAR(10)  NOT NULL,
  QTY      INT          NOT NULL,
  PRIMARY KEY (ITEMID)
);

-- Orders table
CREATE TABLE ORDERS (
  ORDERID           INT            NOT NULL,
  USERID            VARCHAR(80)    NOT NULL,
  ORDERDATE         DATE           NOT NULL,
  SHIPADDR1         VARCHAR(80)    NOT NULL,
  SHIPADDR2         VARCHAR(80),
  SHIPCITY          VARCHAR(80)    NOT NULL,
  SHIPSTATE         VARCHAR(80)    NOT NULL,
  SHIPZIP           VARCHAR(20)    NOT NULL,
  SHIPCOUNTRY       VARCHAR(20)    NOT NULL,
  BILLADDR1         VARCHAR(80)    NOT NULL,
  BILLADDR2         VARCHAR(80),
  BILLCITY          VARCHAR(80)    NOT NULL,
  BILLSTATE         VARCHAR(80)    NOT NULL,
  BILLZIP           VARCHAR(20)    NOT NULL,
  BILLCOUNTRY       VARCHAR(20)    NOT NULL,
  COURIER           VARCHAR(80)    NOT NULL,
  TOTALPRICE        DECIMAL(10,2)  NOT NULL,
  BILLTOFIRSTNAME   VARCHAR(80)    NOT NULL,
  BILLTOLASTNAME    VARCHAR(80)    NOT NULL,
  SHIPTOFIRSTNAME   VARCHAR(80)    NOT NULL,
  SHIPTOLASTNAME    VARCHAR(80)    NOT NULL,
  CREDITCARD        VARCHAR(80)    NOT NULL,
  EXPRDATE          VARCHAR(7)     NOT NULL,
  CARDTYPE          VARCHAR(80)    NOT NULL,
  LOCALE            VARCHAR(80)    NOT NULL,
  PRIMARY KEY (ORDERID)
);

-- Order status table
CREATE TABLE ORDERSTATUS (
  ORDERID   INT         NOT NULL,
  LINENUM   INT         NOT NULL,
  TIMESTAMP DATE        NOT NULL,
  STATUS    VARCHAR(2)  NOT NULL,
  PRIMARY KEY (ORDERID, LINENUM)
);

-- Line item table
CREATE TABLE LINEITEM (
  ORDERID     INT            NOT NULL,
  LINENUM     INT            NOT NULL,
  ITEMID      VARCHAR(10)    NOT NULL,
  QUANTITY    INT            NOT NULL,
  UNITPRICE   DECIMAL(10,2)  NOT NULL,
  PRIMARY KEY (ORDERID, LINENUM)
);

-- Sequence table (used by app for order ID generation)
CREATE TABLE SEQUENCE (
  NAME     VARCHAR(30)  NOT NULL,
  NEXTID   INT          NOT NULL,
  PRIMARY KEY (NAME)
);

SQLEOF

# Import the seed data from the cloned repo
echo "      Importing seed data..."
sudo mysql -u root -p"$DB_ROOT_PASS" "$DB_NAME" \
  < /tmp/jpetstore-6/src/main/resources/database/jpetstore-hsqldb-dataload.sql

# Verify tables and row counts
echo "      Verifying tables and data..."
sudo mysql -u root -p"$DB_ROOT_PASS" "$DB_NAME" -e "SHOW TABLES;"
sudo mysql -u root -p"$DB_ROOT_PASS" "$DB_NAME" -e "SELECT COUNT(*) AS total_products FROM PRODUCT;"
sudo mysql -u root -p"$DB_ROOT_PASS" "$DB_NAME" -e "SELECT COUNT(*) AS total_items    FROM ITEM;"
sudo mysql -u root -p"$DB_ROOT_PASS" "$DB_NAME" -e "SELECT COUNT(*) AS total_categories FROM CATEGORY;"

# -----------------------------------------------------------------------------
# STEP 6 — Open firewall port 3306
# -----------------------------------------------------------------------------
echo "[6/7] Configuring firewall..."

sudo systemctl start firewalld
sudo systemctl enable firewalld
sudo firewall-cmd --zone=public --add-port=3306/tcp --permanent
sudo firewall-cmd --reload

# -----------------------------------------------------------------------------
# STEP 7 — Restart MariaDB
# -----------------------------------------------------------------------------
echo "[7/7] Restarting MariaDB..."
sudo systemctl restart mariadb

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo ""
echo "##################################################"
echo "   Provisioning Complete!"
echo "##################################################"
echo "  DB Host     : 0.0.0.0 (port 3306)"
echo "  DB Name     : ${DB_NAME}"
echo "  DB User     : ${DB_USER}"
echo "  DB Password : ${DB_USER_PASS}"
echo "  Schema      : MySQL-native (no HSQLDB dependency)"
echo "##################################################"
echo ""
echo "  Connect from app VM using:"
echo "  jdbc:mysql://192.168.56.15:3306/${DB_NAME}"
echo "  Username: ${DB_USER} / Password: ${DB_USER_PASS}"
echo "##################################################"
