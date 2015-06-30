FROM google/debian:wheezy

RUN apt-get update
RUN apt-get -qq -y install curl

RUN echo "deb http://debian.datastax.com/community stable main" | tee -a /etc/apt/sources.list.d/cassandra.sources.list
RUN sed -i 's/gce_debian_mirror.storage.googleapis.com wheezy main/gce_debian_mirror.storage.googleapis.com wheezy main non-free/' /etc/apt/sources.list
RUN curl -L http://debian.datastax.com/debian/repo_key | apt-key add -

RUN apt-get update
# RUN apt-get -qq -y install openjdk-7-jre dsc21=2.1.4-1 cassandra=2.1.4
RUN apt-get -qq -y install openjdk-7-jre dsc21=2.1.5-1 cassandra=2.1.5

COPY cassandra.yaml /etc/cassandra/cassandra.yaml
COPY run.sh /run.sh
COPY kubernetes-cassandra.jar /kubernetes-cassandra.jar
RUN chmod a+x /run.sh

# Storage Port, JMX, Thrift, CQL Native, OpsCenter Agent
# Left out: SSL
EXPOSE 7000 7199 9042 9160 61621

CMD /run.sh
