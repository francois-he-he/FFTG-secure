#!/bin/sh

# Simple postfix content filter. It is meant to be invoked as follows:
#       /path/to/script -f sender recipients...
 
# Localize these. The -G option does nothing before Postfix 2.3.
INSPECT_DIR=/var/spool/filter
SENDMAIL="/usr/sbin/sendmail -G -i" # NEVER NEVER NEVER use "-t" here.
 
# Exit codes from <sysexits.h>
EX_TEMPFAIL=75
EX_UNAVAILABLE=69


# Clean up when done or when aborting.
trap "rm -f *.$$" 0 1 2 3 15

# Start processing.
cd $INSPECT_DIR || {
echo $INSPECT_DIR does not exist; exit $EX_TEMPFAIL; }

date=$(date -R)


echo -n "\n\n$date - $2 => $3 - Debut du traitement" >>log.filter
 

#Ecriture du mail dans fichier
cat >in.$$ || { 
echo -n "\n$date - $2 => $3 - Cannot save mail to file" >>log.filter; echo -n "\n$date - $2 => $3 - Fin du traitement" >>log.filter;exit $EX_TEMPFAIL; }

#Recuparation de l'entete et du corps du mail
        sed -e "1,/^$/d" in.$$ > corps.$$
        sed -e "/^$/q" in.$$ > entete.$$
#recuperation des noms de domaines de l'expediteur et du destinataire
echo "$2" | cut -d@ -f2 > exp.$$
echo "$3" | cut -d@ -f2 > des.$$

if cmp exp.$$ des.$$ ; then	  									#si les adresses sont du même domaine, signature uniquement
	gpg --homedir /var/spool/filter -u $2 -o sign.$$ --clearsign corps.$$				# signature
	echo -n "\n$date - $2 => $3 - Signature par $2 uniquement car exp et dest sont du meme domaine" >>log.filter
	cat entete.$$ > mail.$$                                                               		#contruction du mail a reinjecter
        cat sign.$$ >> mail.$$
	echo -n "\n\n\n\n$date - $2 => $3 - SIGNATURE EFFECTUEE AUTOMATIQUEMENT PAR CONTENT_FILTER" >>mail.$$
 	$SENDMAIL  "$@" <mail.$$										 
	echo -n "\n$date - $2 => $3 - Fin du traitement" >>log.filter
	cp *.$$ ./temp											#sauvegarde des fichiers temporaires créés par le process
	exit 
else
	if gpg --homedir /var/spool/filter -u $3 --decrypt corps.$$ ; then				#test si corps du message chiffré ou non
		 echo -n "\n$date - $2 => $3 - reception d'un message chiffré pour $3" >>log.filter
	 	 gpg --homedir /var/spool/filter -u $3 -o decrypt.$$ --decrypt corps.$$ 	 	#dechiffrement du corps du message
	  
	 	 if gpg --homedir /var/spool/filter --verify decrypt.$$ ; then				#test si la signature du corps du mail est valide
			  echo -n "\n$date - $2 => $3 - Signature $2 valide" >>log.filter
		 	  cat entete.$$ > mail.$$							#contruction du mail a reinjecter
	         	  cat decrypt.$$ >> mail.$$							#
		  	  echo -n "\n\n\n\n$date - $2 => $3 - MESSAGE DECHIFFRE ET SIGNATURE VERIFIEE PAR CONTENT_FILTER" >>mail.$$
	  	  	  $SENDMAIL  "$@" <mail.$$							#reinjection du mail via pickup
	  	 else
			  echo -n "\n$date - $2 => $3 - Signature $2 invalide" >>log.filter
	  	 	  exit 
	         fi
	else
		 gpg --homedir /var/spool/filter -u $2 -o sign.$$ --clearsign corps.$$			#signature du corps du mail 
        	 echo -n "\n$date - $2 => $3 - Signature par $2" >>log.filter
		 gpg --homedir /var/spool/filter -r $3 -o encrypt.$$ --armor --encrypt sign.$$		#chiffrement du corps du mail signé
         	 echo -n "\n$date - $2 => $3 - Chiffrement pour $3" >>log.filter
		 cat entete.$$ > mail.$$								#contruction du mail àa reinjecter
        	 cat encrypt.$$ >> mail.$$		 						#
		 $SENDMAIL  "$@" <mail.$$								#reinjection du mail via pickup
	fi

echo "\n$date - $2 => $3 - Fin du traitement" >>log.filter

fi

cp *.$$ ./temp											#sauvegarde des fichiers temporaires créés par le process

exit 0

