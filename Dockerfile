## License
# MIT License
# See included LICENSE document or https://opensource.org/licenses/MIT

FROM chrisyx511/baseimagealpine:latest
RUN apk add --no-cache btrfs-progs
COPY /root /
RUN mkdir /config

ENV HOURLY_SNAP true
ENV HOURLY_SNAP_KEEP 24

ENV DAILY_SNAP true
ENV DAILY_SNAP_KEEP 7

ENV WEEKLY_SNAP true
ENV WEEKLY_SNAP_KEEP 5

ENV MONTHLY_SNAP true
ENV MONTHLY_SNAP_KEEP 12