#/bin/sh

composer self-update 2.3.4
mkdir /var/www
mkdir /var/www/html
cd /var/www/html/
read -p "Enter the Magento Version :" version
composer create-project --no-install --repository-url=https://repo.magento.com/ magento/project-community-edition=$version /var/www/html/magento
cd /var/www/html/magento
composer config allow-plugins.laminas/laminas-dependency-plugin true
composer config allow-plugins.magento/* true
composer config allow-plugins.dealerdirect/phpcodesniffer-composer-installer true
composer install
find var generated vendor pub/static pub/media app/etc -type f -exec chmod g+w {} + 
find var generated vendor pub/static pub/media app/etc -type d -exec chmod g+ws {} + 
chown -R root:www-data . 
chmod u+x bin/magento 
chmod -R 777  pub/static generated/ var/cache/
php bin/magento setup:install --base-url=http://pharmastaging.local.com/ --db-host=localhost --db-name=magento --db-user=magento --db-password=magento --admin-firstname=admin --admin-lastname=admin --admin-email=admin@admin.com --admin-user=admin --admin-password=admin123 --language=en_US --currency=USD --timezone=Asia/Kolkata --use-rewrites=1

#cp /root/.composer/auth.json /var/www/html/magento/var/composer_home/auth.json
find var generated vendor pub/static pub/media app/etc -type f -exec chmod g+w {} + 
find var generated vendor pub/static pub/media app/etc -type d -exec chmod g+ws {} + 
chown -R root:www-data . 
chmod u+x bin/magento 
chmod -R 777  pub/static generated/ var/cache/ 
#printf "yes" | php -d memory_limit=-1 bin/magento sampledata:deploy
php bin/magento se:up 
php bin/magento module:disable Magento_TwoFactorAuth
php bin/magento setup:di:compile
php bin/magento setup:static-content:deploy -f
php bin/magento c:c && php bin/magento c:f
chown -R root:www-data .
chmod -R 777  pub/static generated/ var/cache
chmod -R 777 pub/static generated/ var/  
chown -R www-data:magento .
