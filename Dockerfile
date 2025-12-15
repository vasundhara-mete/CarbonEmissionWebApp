FROM tomcat:9.0-jdk21
RUN rm -rf /usr/local/tomcat/webapps/*
# Path must be app/ROOT.war because Dockerfile is now in the root
COPY app/ROOT.war /usr/local/tomcat/webapps/ROOT.war
EXPOSE 8080
CMD ["catalina.sh", "run"]