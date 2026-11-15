enum FeaturedMessageStatus { noReceiver, sent, rendered, disconnected }

class FeaturedMessageDelivery {
  FeaturedMessageDelivery(this.id, this.status, this.completed);

  factory FeaturedMessageDelivery.noReceiver() => FeaturedMessageDelivery(
        null,
        FeaturedMessageStatus.noReceiver,
        Future.value(FeaturedMessageStatus.noReceiver),
      );

  final String? id;
  final FeaturedMessageStatus status;
  final Future<FeaturedMessageStatus> completed;
}
